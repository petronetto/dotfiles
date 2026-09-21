#!/usr/bin/env zsh

# Ollama wrapper: injects server configuration and manages a background server.
#
#   ollama start   start `ollama serve` detached in the background
#   ollama stop    stop the background server
#   ollama ...     anything else runs the real ollama CLI with the env vars set
#
# Supported server environment variables (defaults in parentheses):
#   OLLAMA_DEBUG                 show additional debug information (off)
#   OLLAMA_HOST                  IP address for the ollama server (127.0.0.1:11434)
#   OLLAMA_CONTEXT_LENGTH        context length unless otherwise specified (VRAM-based)
#   OLLAMA_KEEP_ALIVE            duration models stay loaded in memory (5m)
#   OLLAMA_MAX_LOADED_MODELS     maximum number of loaded models per GPU (3)
#   OLLAMA_MAX_TRANSFER_STREAMS  parallel transfer streams for pulls/pushes (4)
#   OLLAMA_MAX_QUEUE             maximum number of queued requests (500)
#   OLLAMA_MODELS                path to the models directory (~/.ollama/models)
#   OLLAMA_NUM_PARALLEL          maximum number of parallel requests (auto)
#   OLLAMA_NO_CLOUD              disable Ollama cloud features (off)
#   OLLAMA_NOPRUNE               do not prune model blobs on startup (off)
#   OLLAMA_ORIGINS               comma separated list of allowed origins (local only)
#   OLLAMA_SCHED_SPREAD          always schedule models across all GPUs (off)
#   OLLAMA_FLASH_ATTENTION       enable flash attention (on)
#   OLLAMA_KV_CACHE_TYPE         K/V cache quantization type (f16)
#   OLLAMA_LLM_LIBRARY           LLM library to bypass autodetection (auto)
#   OLLAMA_GPU_OVERHEAD          VRAM reserved per GPU in bytes (0)
#   OLLAMA_IGPU_ENABLE           enable integrated GPUs (auto)
#   LLAMA_ARG_FIT                llama.cpp automatic fit of unset memory options (on)
#   LLAMA_ARG_FIT_TARGET         target free VRAM margin per device in MiB (0)
#   OLLAMA_LOAD_TIMEOUT          how long model loads may stall before giving up (5m)

# Server configuration, applied to `start` and exported for every command.
# Keep OLLAMA_HOST commented out unless changed: the port check below assumes
# the default 127.0.0.1:11434.
function _ollama_env() {
  export OLLAMA_NUM_PARALLEL=3
  export OLLAMA_MAX_LOADED_MODELS=2
  export OLLAMA_KV_CACHE_TYPE=q8_0
  export OLLAMA_CONTEXT_LENGTH=131072
  export OLLAMA_KEEP_ALIVE=30m
  export OLLAMA_FLASH_ATTENTION=1
  # export OLLAMA_HOST=127.0.0.1:11434
  # export OLLAMA_MODELS="$HOME/.ollama/models"
  # export OLLAMA_NO_CLOUD=1
}

# Returns 0 when the pid in $1 is a live `ollama serve` process.
function _ollama_pid_is_serve() {
  [[ -n "$1" ]] && ps -p "$1" -o command= 2>/dev/null | grep -q "ollama serve"
}

function _ollama_start() {
  local log_file="$HOME/.ollama/logs/serve.log"
  local pid_file="$HOME/.ollama/serve.pid"
  local port=11434
  local pid=""

  mkdir -p "$HOME/.ollama/logs"

  if [[ -s "$pid_file" ]]; then
    pid=$(<"$pid_file")
    if _ollama_pid_is_serve "$pid"; then
      print "ollama is already running (pid $pid)"
      return 0
    fi
  fi

  if lsof -nP -iTCP:"$port" -sTCP:LISTEN &>/dev/null; then
    print "ERROR! Port $port is already in use:" >&2
    lsof -nP -iTCP:"$port" -sTCP:LISTEN >&2
    print "Hint: stop the other instance first (brew services stop ollama)." >&2
    return 1
  fi

  _ollama_env
  nohup ollama serve "$@" >>"$log_file" 2>&1 &
  pid=$!
  disown
  print "$pid" > "$pid_file"

  # Wait until the API answers, so the prompt only returns when it is usable
  local i
  for i in {1..40}; do
    if ! kill -0 "$pid" 2>/dev/null; then
      print "ERROR! ollama exited during startup, last log lines:" >&2
      tail -n 10 "$log_file" >&2
      rm -f "$pid_file"
      return 1
    fi
    if curl -fsS "http://127.0.0.1:$port/" &>/dev/null; then
      print "ollama started (pid $pid, log $log_file)"
      return 0
    fi
    sleep 0.25
  done

  print "ERROR! ollama did not answer on port $port within 10s, check $log_file" >&2
  return 1
}

function _ollama_stop() {
  local pid_file="$HOME/.ollama/serve.pid"
  local pid=""

  [[ -s "$pid_file" ]] && pid=$(<"$pid_file")

  if ! _ollama_pid_is_serve "$pid"; then
    if lsof -nP -iTCP:11434 -sTCP:LISTEN &>/dev/null; then
      print "ERROR! ollama is running but not managed by this wrapper:" >&2
      lsof -nP -iTCP:11434 -sTCP:LISTEN >&2
      print "Hint: brew services stop ollama" >&2
      return 1
    fi
    print "ollama is not running"
    rm -f "$pid_file"
    return 0
  fi

  kill "$pid" 2>/dev/null

  # Give it up to 5s to exit cleanly, then force kill
  local i
  for i in {1..20}; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.25
  done
  kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null

  rm -f "$pid_file"
  print "ollama stopped (pid $pid)"
}

function ollama() {
  case $1 in
    start)
      shift
      _ollama_start "$@"
      ;;
    stop)
      _ollama_stop
      ;;
    *)
      _ollama_env
      command ollama "$@"
      ;;
  esac
}
