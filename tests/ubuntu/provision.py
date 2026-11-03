#!/usr/bin/env python3
"""Provision an isolated Ubuntu fixture through a real sudo password challenge."""

import argparse
import errno
import json
import os
import platform
import pty
import pwd
import select
import secrets
import signal
import subprocess
import sys
import termios
import time
import tomllib
from dataclasses import dataclass
from pathlib import Path
from typing import TextIO


SOURCE = Path("/home/tester/.local/share/chezmoi")
MANIFEST = Path("/opt/dotfiles-fixture/manifest.json")


@dataclass(frozen=True)
class PtyCommand:
    arguments: list[str]
    environment: dict[str, str]
    account: pwd.struct_passwd | None = None


def run_pty(request: PtyCommand, password: str, output: TextIO, timeout: float = 3600) -> int:
    process, descriptor = pty.fork()
    if process == 0:
        if request.account is not None:
            account = request.account
            os.initgroups(account.pw_name, account.pw_gid)
            os.setgid(account.pw_gid)
            os.setuid(account.pw_uid)
        os.execvpe(request.arguments[0], request.arguments, request.environment)
    attributes = termios.tcgetattr(descriptor)
    attributes[3] &= ~termios.ECHO
    termios.tcsetattr(descriptor, termios.TCSANOW, attributes)
    pending = b""
    prompt = b""
    secret = password.encode()
    deadline = time.monotonic() + timeout
    timed_out = False
    try:
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                os.killpg(process, signal.SIGKILL)
                timed_out = True
                break
            if not select.select([descriptor], [], [], min(remaining, 1))[0]:
                continue
            try:
                data = os.read(descriptor, 4096)
            except OSError as error:
                if error.errno != errno.EIO:
                    raise
                break
            if not data:
                break
            prompt = (prompt + data)[-512:]
            if b"password for tester:" in prompt.lower():
                os.write(descriptor, secret + b"\n")
                prompt = b""
            pending = (pending + data).replace(secret, b"[redacted]")
            if len(pending) > len(secret):
                output.write(pending[:-len(secret)].decode("utf-8", errors="replace"))
                output.flush()
                pending = pending[-len(secret):]
    finally:
        os.close(descriptor)
    output.write(pending.replace(secret, b"[redacted]").decode("utf-8", errors="replace"))
    _, status = os.waitpid(process, 0)
    if timed_out:
        output.write("\nbootstrap timed out; fixture is preserved\n")
        return 124
    code = os.waitstatus_to_exitcode(status)
    return code if code >= 0 else 128 - code


def fixture_account() -> pwd.struct_passwd:
    if os.geteuid() != 0 or platform.system() != "Linux" or not Path("/.dockerenv").exists():
        raise ValueError("provisioning requires root inside the isolated Docker fixture")
    if platform.machine() != "x86_64" or not MANIFEST.is_file():
        raise ValueError("an AMD64 fixture with source evidence is required")
    if json.loads(MANIFEST.read_text()).get("platform") != "linux/amd64":
        raise ValueError("fixture source evidence must identify linux/amd64")
    release = Path("/etc/os-release").read_text()
    if "ID=ubuntu\n" not in release or 'VERSION_ID="26.04"' not in release:
        raise ValueError("Ubuntu 26.04 is required")
    account = pwd.getpwnam("tester")
    if account.pw_uid == 0 or account.pw_dir != "/home/tester":
        raise ValueError("fixture tester account has unexpected ownership or home")
    return account


def prepare_configuration(account: pwd.struct_passwd) -> None:
    config = Path(account.pw_dir) / ".config/chezmoi/chezmoi.toml"
    if config.exists():
        data = tomllib.loads(config.read_text()).get("data", {})
        if data.get("profile") != "test-container" or data.get("git_email") != "tester@example.invalid":
            raise ValueError("refusing to overwrite non-fixture chezmoi initialization data")
        return
    config.parent.mkdir(parents=True, mode=0o700)
    config.write_text('[data]\ngit_email = "tester@example.invalid"\nprofile = "test-container"\n')
    config.chmod(0o600)
    for path in (config.parent.parent, config.parent, config):
        os.chown(path, account.pw_uid, account.pw_gid)


def change_password(value: str, encrypted: bool = False) -> None:
    arguments = ["chpasswd"]
    if encrypted:
        arguments.append("--encrypted")
    subprocess.run(arguments, input=f"tester:{value}\n", text=True, check=True, capture_output=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("root", "user"), default="root")
    arguments = parser.parse_args()
    try:
        account = fixture_account()
        prepare_configuration(account)
        original_hash = next(line.split(":")[1] for line in Path("/etc/shadow").read_text().splitlines()
                             if line.startswith("tester:"))
        password = secrets.token_urlsafe(32)
        command = ["bash", str(SOURCE / "bootstrap.sh"), "--source", str(SOURCE), "--profile", "test-container"]
        environment = {
            "HOME": account.pw_dir, "USER": "tester", "LOGNAME": "tester", "TERM": "xterm-256color",
            "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "LANG": "C.UTF-8",
        }
        selected_account = account
        if arguments.mode == "root":
            command.extend(["--user", "tester"])
            environment.update(HOME="/root", USER="root", LOGNAME="root")
            selected_account = None
        change_password(password)
        try:
            print(f"Fixture bootstrap mode: {arguments.mode}", flush=True)
            return run_pty(PtyCommand(command, environment, selected_account), password, sys.stdout)
        finally:
            change_password(original_hash, encrypted=True)
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f"Fixture provisioning failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
