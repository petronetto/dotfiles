#!/usr/bin/env python3
"""voice-whisperd: a tiny local HTTP transcription daemon.

Loads the cached openai-whisper "large-v3-turbo" model once at startup and
keeps it in memory so per-utterance transcription pays no model-load cost.
Exposes POST /transcribe (WAV in, JSON {"text": ...} out) and GET /health.
Self-exits after an idle timeout without requests; the LaunchAgent that runs
it uses KeepAlive=false, so launchd never re-spawns it. Stdlib only.

Env overrides (all optional):
  VOICE_WHISPERD_HOST          bind address (default 127.0.0.1, localhost only)
  VOICE_WHISPERD_PORT          port (default 8765)
  VOICE_WHISPERD_MODEL         whisper model name (default large-v3-turbo)
  VOICE_WHISPERD_IDLE_TIMEOUT  seconds of no traffic before self-exit (default 600)
"""

import json
import os
import signal
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

def log(message: str):
    """Emit an observability line immediately.

    Stdlib stdout is fully buffered when redirected to a file or a pipe (the
    LaunchAgent and the test both run this way), so progress lines would be
    invisible until a large buffer filled or the process exited. Flush every
    line so logs stay observable and the in-memory-model proof in the test works.
    """
    print(message, flush=True)

HOST = os.environ.get("VOICE_WHISPERD_HOST", "127.0.0.1")
PORT = int(os.environ.get("VOICE_WHISPERD_PORT", "8765"))
MODEL_NAME = os.environ.get("VOICE_WHISPERD_MODEL", "large-v3-turbo")
IDLE_TIMEOUT = float(os.environ.get("VOICE_WHISPERD_IDLE_TIMEOUT", "600"))

# Populated by load_model() at startup; read by the request handlers.
_model = None
_device = ""
_fp16 = False
_started_at = time.time()
_stop = threading.Event()

# Idle accounting: a request in flight never counts as idle, so the daemon
# cannot shut down mid-transcription (e.g. a slow first inference).
_activity_lock = threading.Lock()
_last_activity = time.time()
_inflight = 0


def touch(increment=False, decrement=False):
    """Record activity, optionally entering/leaving an in-flight request."""
    global _last_activity, _inflight
    with _activity_lock:
        _last_activity = time.time()
        if increment:
            _inflight += 1
        if decrement:
            _inflight -= 1


def load_model():
    """Load the cached model once onto MPS when available, else CPU."""
    global _model, _device, _fp16
    import torch
    import whisper

    use_mps = torch.backends.mps.is_available()
    _device = "mps" if use_mps else "cpu"
    _fp16 = use_mps
    _model = whisper.load_model(MODEL_NAME, device=torch.device(_device))
    return _model


def extract_wav_bytes(content_type, body):
    """Return the WAV payload from a multipart/form-data POST or a raw body.

    Multipart is parsed by hand (stdlib has no form-data parser) to isolate the
    first file part; any other Content-Type is treated as a raw WAV body.
    """
    if not content_type.startswith("multipart/form-data"):
        return body

    boundary = ""
    for token in content_type.split(";"):
        if token.strip().startswith("boundary="):
            boundary = token.split("=", 1)[1].strip().strip('"')
    if not boundary:
        return body

    delimiter = b"--" + boundary.encode()
    for part in body.split(delimiter):
        raw = part.strip(b"\r\n")
        headers, sep, data = raw.partition(b"\r\n\r\n")
        if not sep:
            continue
        dispo = ""
        for line in headers.split(b"\r\n"):
            if line.lower().startswith(b"content-disposition"):
                dispo = line.decode("ascii", "replace")
        if "filename" in dispo or "form-data" in dispo:
            return data
    return body


def transcribe(wav_bytes):
    """Decode a WAV payload and transcribe it; returns trimmed text."""
    import tempfile

    with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
        tmp.write(wav_bytes)
        tmp.flush()
        result = _model.transcribe(
            tmp.name,
            fp16=_fp16,
            language="en",
            condition_on_previous_text=False,
        )
    return result.get("text", "").strip()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *_):
        pass  # stay quiet; /health exposes request count instead

    def send_json(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        touch()
        if self.path == "/health":
            self.send_json(200, {
                "status": "ok",
                "model": MODEL_NAME,
                "device": _device,
                "uptime_s": round(time.time() - _started_at, 1),
            })
        else:
            self.send_json(404, {"error": "not found"})

    def do_POST(self):
        touch(increment=True)
        try:
            if self.path != "/transcribe":
                self.send_json(404, {"error": "not found"})
                return
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length) if length else b""
            wav_bytes = extract_wav_bytes(self.headers.get("Content-Type", ""), body)
            text = transcribe(wav_bytes)
            self.send_json(200, {"text": text})
        except Exception as exc:  # report any transcription failure to the client
            self.send_json(500, {"error": str(exc)})
        finally:
            touch(decrement=True)


def serve():
    """Bind the socket, load the model, then serve until idle or stopped."""
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    server.daemon_threads = True

    log(f"voice-whisperd: {MODEL_NAME} on {_device}, "
        f"listening on {HOST}:{PORT} (idle-exit {IDLE_TIMEOUT:.0f}s)")

    load_model()
    log("voice-whisperd: model loaded, ready")

    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    try:
        while not _stop.is_set():
            time.sleep(1)
            with _activity_lock:
                busy = _inflight > 0
                quiet_for = time.time() - _last_activity
            if not busy and quiet_for > IDLE_TIMEOUT:
                log(f"voice-whisperd: idle {IDLE_TIMEOUT:.0f}s, exiting")
                break
    finally:
        server.shutdown()
        server.server_close()
    sys.exit(0)


def request_stop(_signum, _frame):
    _stop.set()


def main():
    signal.signal(signal.SIGINT, request_stop)
    signal.signal(signal.SIGTERM, request_stop)
    try:
        serve()
    except OSError as exc:
        print(f"voice-whisperd: cannot bind {HOST}:{PORT}: {exc}", file=sys.stderr, flush=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
