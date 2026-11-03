#!/usr/bin/env python3
"""Execute catalog-linked Ubuntu smoke checks and write bounded acceptance evidence."""

import argparse
import json
import os
import platform
import re
import shutil
import signal
import subprocess
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


MAX_OUTPUT_BYTES = 8192
MAX_CHECK_SECONDS = 300
SKIPPED_EXIT = 77
TIMEOUT_EXIT = 124
PENDING_MACHINE_CHECKS = [
    "Native GPU rendering and desktop-session integration",
    "Physical keyboard mappings and Nerd Font appearance",
    "Real account/provider authentication and personal vault selection",
    "Unlocked 1Password agent and real Git signing",
    "Host Docker daemon startup and container execution",
    "T2 hardware, PAM, encrypted disks, and deferred Touch ID",
]


def checks_by_command(registry: dict[str, Any], directory: Path) -> dict[str, dict[str, Any]]:
    if registry.get("schema") != 1 or not isinstance(registry.get("checks"), list):
        raise ValueError("invalid smoke registry schema")
    checks = {}
    for check in registry["checks"]:
        command = check.get("command")
        script = check.get("script")
        timeout = check.get("timeout", 30)
        if not isinstance(command, str) or not command.strip() or not isinstance(script, str):
            raise ValueError("registry entries need a command and script")
        if command in checks:
            raise ValueError(f"duplicate registry command: {command}")
        if not isinstance(timeout, (int, float)) or not 0 < timeout <= MAX_CHECK_SECONDS:
            raise ValueError(f"invalid timeout for {command}")
        path = (directory / script).resolve()
        if not path.is_relative_to(directory.resolve()):
            raise ValueError(f"script escapes registry directory: {command}")
        checks[command] = {"script": path, "timeout": timeout}
    return checks


def stop_process(process: subprocess.Popen) -> None:
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()


def execute(command: str, check: dict[str, Any]) -> dict[str, Any]:
    started = time.monotonic()
    with tempfile.TemporaryDirectory(prefix="ubuntu-smoke-") as directory, tempfile.TemporaryFile() as output:
        environment = {**os.environ, "UBUNTU_SMOKE_DIR": directory}
        process = subprocess.Popen(
            ["zsh", "-f", str(check["script"]), command],
            cwd=directory, env=environment, stdin=subprocess.DEVNULL,
            stdout=output, stderr=subprocess.STDOUT, start_new_session=True,
        )
        timed_out = False
        try:
            code = process.wait(timeout=check["timeout"])
        except subprocess.TimeoutExpired:
            stop_process(process)
            timed_out = True
            code = TIMEOUT_EXIT
        output.seek(0)
        data = output.read(MAX_OUTPUT_BYTES + 1)
    text = data[:MAX_OUTPUT_BYTES].decode("utf-8", errors="replace")
    if timed_out:
        text = (f"timed out after {check['timeout']} seconds\n" + text)[:MAX_OUTPUT_BYTES]
    status = "passed" if code == 0 else "failed"
    if code == SKIPPED_EXIT:
        status = "skipped"
    return {
        "command": command, "script": str(check["script"]), "status": status,
        "exit_code": code, "output": text, "output_truncated": len(data) > MAX_OUTPUT_BYTES,
        "duration_seconds": round(time.monotonic() - started, 3),
    }


def missing_result(command: str, status: str, reason: str) -> dict[str, Any]:
    return {"command": command, "status": status, "exit_code": None, "output": reason}


def evidence_errors(manifest: dict[str, Any], runtime: dict[str, Any]) -> list[str]:
    errors = []
    if not re.fullmatch(r"[0-9a-f]{64}", str(manifest.get("source_digest", ""))):
        errors.append("missing or invalid source digest")
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", str(manifest.get("image", ""))):
        errors.append("missing or invalid immutable image ID")
    if manifest.get("platform") != "linux/amd64":
        errors.append("source evidence must identify linux/amd64")
    if runtime.get("os") != "Linux" or runtime.get("architecture") != "x86_64":
        errors.append("acceptance requires a real Linux AMD64 runtime")
    if not isinstance(runtime.get("uid"), int) or runtime["uid"] <= 0:
        errors.append("smoke checks must run as a non-root user")
    return errors


def evaluate(
    catalog: dict[str, Any], registry: dict[str, Any], directory: Path,
    manifest: dict[str, Any], ledger: dict[str, Any], runtime: dict[str, Any],
    only: str | None = None,
) -> dict[str, Any]:
    checks = checks_by_command(registry, directory)
    commands = [command for tool in catalog["tools"] for command in tool["commands"]]
    if not commands or len(commands) != len(set(commands)):
        raise ValueError("catalog commands must be nonempty and unique")
    if any(command not in commands for command in checks):
        raise ValueError("registry contains a command absent from the catalog")
    if only is not None and only not in commands:
        raise ValueError(f"unknown focused command: {only}")
    errors = evidence_errors(manifest, runtime)
    can_execute = not errors
    versions = {}
    for tool in catalog["tools"]:
        version = ledger.get(tool["id"], {}).get("installed_version")
        if not isinstance(version, str) or not version.strip():
            errors.append(f"missing installed version evidence: {tool['id']}")
        versions[tool["id"]] = version
    results = []
    for command in commands:
        if not can_execute:
            results.append(missing_result(command, "unexecuted", "invalid source or runtime evidence"))
            continue
        if only is not None and only != command:
            results.append(missing_result(command, "unexecuted", "not selected by focused run"))
            continue
        check = checks.get(command)
        if check is None or not check["script"].is_file():
            results.append(missing_result(command, "missing", "smoke implementation is missing"))
            continue
        if shutil.which(command.split()[0]) is None:
            results.append(missing_result(command, "missing", "installed command is missing"))
            continue
        results.append(execute(command, check))
    passed = not errors and all(result["status"] == "passed" for result in results)
    return {
        "schema": 1, "status": "passed" if passed else "failed",
        "created": datetime.now(timezone.utc).isoformat(),
        "source": manifest, "runtime": runtime, "versions": versions,
        "errors": errors, "results": results, "focused_command": only,
        "pending_machine_checks": PENDING_MACHINE_CHECKS,
    }


def save_report(destination: Path, report: dict[str, Any]) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=destination.parent, delete=False) as pending:
        path = Path(pending.name)
        try:
            json.dump(report, pending, indent=2)
            pending.write("\n")
            pending.flush()
            path.replace(destination)
        finally:
            path.unlink(missing_ok=True)


def read_json(path: Path) -> dict[str, Any]:
    with path.open() as source:
        value = json.load(source)
    if not isinstance(value, dict):
        raise ValueError(f"expected a JSON object: {path}")
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("catalog", "registry", "manifest", "versions", "report"):
        parser.add_argument(f"--{name}", type=Path, required=True)
    parser.add_argument("--only", help="run one command; omitted commands still block full acceptance")
    arguments = parser.parse_args()
    runtime = {"os": platform.system(), "architecture": platform.machine(), "uid": os.geteuid()}
    try:
        report = evaluate(
            read_json(arguments.catalog), read_json(arguments.registry), arguments.registry.parent,
            read_json(arguments.manifest), read_json(arguments.versions), runtime, only=arguments.only,
        )
    except (OSError, ValueError, KeyError, TypeError) as error:
        report = {
            "schema": 1, "status": "failed", "runtime": runtime, "errors": [str(error)],
            "results": [], "pending_machine_checks": PENDING_MACHINE_CHECKS,
        }
    save_report(arguments.report, report)
    for result in report["results"]:
        print(f"{result['status']}: {result['command']}")
    for error in report["errors"]:
        print(f"error: {error}")
    print(f"CLI acceptance: {report['status']}; report: {arguments.report}")
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
