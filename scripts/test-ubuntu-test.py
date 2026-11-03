#!/usr/bin/env python3
"""Docker lifecycle regression tests with an isolated Docker executable."""

import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / "scripts/ubuntu-test"
IMAGE_ID = "sha256:" + "a" * 64

DOCKER = r'''
import json
import os
import shutil
import sys
import tarfile
from pathlib import Path

args = sys.argv[1:]
state_path = Path(os.environ["TEST_CONTAINER_STATE"])
root = state_path.parent / "container"
state = json.loads(state_path.read_text()) if state_path.exists() else {}
with open(os.environ["TEST_LOG"], "a") as log:
    log.write(json.dumps(args) + "\n")
if args[0] == "image":
    print("sha256:" + "a" * 64)
elif args[0] == "pull":
    print("fixture pull")
elif args[0] == "inspect":
    if not state:
        sys.exit(1)
    template = args[args.index("--format") + 1] if "--format" in args else ""
    if "State.Running" in template:
        print(str(state["running"]).lower())
    elif "dotfiles.source-digest" in template:
        print(state["source_digest"] + "|" + state["image"])
    else:
        print(json.dumps(state))
elif args[0] == "compose":
    if "up" in args:
        if state:
            sys.exit("refusing fixture recreation")
        state = {"running": True, "source_digest": os.environ["UBUNTU_TEST_SOURCE_DIGEST"],
                 "image": "sha256:" + "a" * 64,
                 "owners": {"/": "root", "/home": "root", "/home/tester": "tester"}}
        state_path.write_text(json.dumps(state))
        root.mkdir(exist_ok=True)
elif args[0] in ("start", "stop"):
    state["running"] = args[0] == "start"
    state_path.write_text(json.dumps(state))
elif args[0] == "cp":
    source, destination = args[1:]
    if ":" in source:
        source = root / source.split(":", 1)[1].lstrip("/")
        target = Path(destination)
    else:
        target = root / destination.split(":", 1)[1].lstrip("/")
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
elif args[0] == "exec":
    command = args[args.index("ubuntu-dotfiles-test") + 1:]
    if command[0] == "mkdir":
        user = args[args.index("--user") + 1]
        for directory in (value for value in command[1:] if value.startswith("/")):
            target = root / directory.lstrip("/")
            target.mkdir(parents=True, exist_ok=True)
            path = Path(directory)
            for parent in (path, *path.parents):
                state["owners"].setdefault(str(parent), user)
        state_path.write_text(json.dumps(state))
    elif command[0] == "chown":
        target = command[-1]
        for path in state["owners"]:
            if path == target or path.startswith(target + "/"):
                state["owners"][path] = "tester"
        state_path.write_text(json.dumps(state))
    elif command[0] == "bsdtar":
        archive = root / command[command.index("-xf") + 1].lstrip("/")
        destination = root / command[command.index("-C") + 1].lstrip("/")
        destination.mkdir(parents=True, exist_ok=True)
        with tarfile.open(archive) as tar:
            tar.extractall(destination, filter="data")
    elif command[:2] == ["zsh", "-f"]:
        report = root / "home/tester/.local/state/dotfiles/ubuntu-test/report.json"
        report.parent.mkdir(parents=True, exist_ok=True)
        report.write_text(json.dumps({"status": "failed", "results": []}))
        sys.exit(6)
    elif command[0] == "zsh" and os.environ.get("TEST_SHELL_FAILURE"):
        sys.exit(7)
elif args[0] == "logs":
    print("fixture logs")
else:
    sys.exit("unexpected Docker operation: " + repr(args))
'''


class UbuntuTestFixtureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.state = self.root / "container.json"
        self.log = self.root / "commands.jsonl"
        executable = self.bin / "docker"
        executable.write_text("#!/usr/bin/env python3\n" + DOCKER)
        executable.chmod(0o755)
        self.env = {
            "HOME": str(self.root),
            "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
            "TEST_LOG": str(self.log),
            "TEST_CONTAINER_STATE": str(self.state),
        }
        self.source = self.root / "source"
        self.source.mkdir()
        subprocess.run(["git", "init", "-q", str(self.source)], check=True,
                       env={**os.environ, "GIT_CONFIG_GLOBAL": os.devnull}, timeout=10)
        for relative, content in {
            ".chezmoi.toml.tmpl": "[data]\n",
            "bootstrap.sh": "#!/bin/bash\n",
            "symlink_dot_zshenv": ".config/zsh/.zshenv\n",
            "dot_config/zsh/dot_zshrc": "fixture shell\n",
            "scripts/install-ubuntu-packages": "#!/usr/bin/env zsh\n",
            "tests/ubuntu/smoke/registry.json": "[]\n",
        }.items():
            path = self.source / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)

    def run_script(self, *args, **environment):
        return subprocess.run(
            ["zsh", str(SCRIPT), *args, "--source", str(self.source)],
            capture_output=True, text=True, timeout=15,
            env={**self.env, **environment},
        )

    def prepare(self):
        result = self.run_script("prepare")
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def manifest(self):
        path = self.root / ".local/state/dotfiles/ubuntu-test/manifest.json"
        return json.loads(path.read_text())

    def commands(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_prepare_transfers_complete_current_public_source_without_ssh_inputs(self):
        self.prepare()

        source = self.root / "container/home/tester/.local/share/chezmoi"
        self.assertEqual((source / "symlink_dot_zshenv").read_text(), ".config/zsh/.zshenv\n")
        self.assertEqual((source / "dot_config/zsh/dot_zshrc").read_text(), "fixture shell\n")
        self.assertTrue((source / "tests/ubuntu/smoke/registry.json").is_file())
        self.assertFalse(any("ssh" in str(command) for command in self.commands()))

    def test_prepared_source_does_not_leave_root_owned_user_data_parents(self):
        self.prepare()

        owners = json.loads(self.state.read_text())["owners"]

        for directory in ("/home/tester/.local", "/home/tester/.local/share", "/home/tester/.local/share/chezmoi"):
            self.assertEqual(owners[directory], "tester", directory)

    def test_snapshot_excludes_ignored_private_and_symlink_escape_files(self):
        (self.source / ".gitignore").write_text("scripts/ignored-token\n")
        for relative in ("scripts/ignored-token", "private/credential", "scripts/private/key",
                         "dot_config/private/secret", "scripts/key.age", "unrelated.txt"):
            path = self.source / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("synthetic content\n")
        (self.source / "scripts/escape").symlink_to(self.root)

        self.prepare()

        files = self.manifest()["files"]
        for forbidden in ("ignored-token", "credential", "private/", "key.age", "unrelated.txt", "escape", ".git/"):
            self.assertFalse(any(forbidden in path for path in files), forbidden)

    def test_source_archive_excludes_host_metadata_and_uses_root_ownership(self):
        source_file = self.source / "dot_config/zsh/dot_zshrc"
        if sys.platform == "darwin":
            subprocess.run(["xattr", "-w", "com.example.dotfiles-fixture", "synthetic host metadata", str(source_file)],
                           check=True, timeout=5)
        else:
            os.setxattr(source_file, "user.dotfiles-fixture", b"synthetic host metadata")

        self.prepare()

        archive = self.root / "container/opt/dotfiles-fixture/source.tar"
        with tarfile.open(archive) as snapshot:
            member = snapshot.getmember("dot_config/zsh/dot_zshrc")
            self.assertEqual((member.uid, member.gid, member.uname, member.gname), (0, 0, "root", "root"))
            self.assertFalse(any("xattr" in name for name in member.pax_headers))

    def test_manifest_identifies_source_image_platform_and_creation_time(self):
        self.prepare()

        evidence = self.manifest()
        self.assertRegex(evidence["source_digest"], r"^[0-9a-f]{64}$")
        self.assertEqual(evidence["image"], IMAGE_ID)
        self.assertEqual(evidence["platform"], "linux/amd64")
        self.assertRegex(evidence["created"], r"^\d{4}-\d{2}-\d{2}T")

    def test_prepare_reuses_running_or_stopped_container_and_preserves_manual_files(self):
        self.prepare()
        manual = self.root / "container/manual.txt"
        manual.write_text("retain me\n")

        repeated = self.run_script("prepare")
        stopped = self.run_script("stop")
        resumed = self.run_script("start")

        for result in (repeated, stopped, resumed):
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(manual.read_text(), "retain me\n")
        self.assertTrue(json.loads(self.state.read_text())["running"])
        self.assertEqual(sum("up" in command for command in self.commands()), 1)

    def test_staging_or_touching_unchanged_source_does_not_invalidate_the_container(self):
        self.prepare()
        (self.source / "dot_config/zsh/dot_zshrc").touch()
        subprocess.run(["git", "-C", str(self.source), "add", "--", "."],
                       check=True, timeout=10)

        result = self.run_script("start")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(self.state.read_text())["running"])

    def test_changed_working_tree_refuses_reuse_even_when_container_is_stopped(self):
        self.prepare()
        self.run_script("stop")
        (self.source / "dot_config/zsh/dot_zshrc").write_text("changed source\n")

        result = self.run_script("start")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fingerprint mismatch", result.stderr)
        self.assertFalse(json.loads(self.state.read_text())["running"])
        self.assertFalse(any(command[0] == "rm" for command in self.commands()))

    def test_changed_image_refuses_reuse_without_deleting_container(self):
        self.prepare()
        state = json.loads(self.state.read_text())
        state["image"] = "sha256:" + "b" * 64
        self.state.write_text(json.dumps(state))

        result = self.run_script("prepare")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fingerprint mismatch", result.stderr)
        self.assertFalse(any(command[0] == "rm" for command in self.commands()))

    def test_shell_uses_non_root_login_shell_and_keeps_container_after_failure(self):
        self.prepare()

        result = self.run_script("shell", TEST_SHELL_FAILURE="1")

        self.assertEqual(result.returncode, 7)
        self.assertIn(["exec", "-it", "--user", "tester", "ubuntu-dotfiles-test", "zsh", "-l"], self.commands())
        self.assertTrue(json.loads(self.state.read_text())["running"])

    def test_check_copies_failure_report_and_leaves_container_running(self):
        self.prepare()

        result = self.run_script("check", "--only", "zsh")

        self.assertEqual(result.returncode, 6, result.stderr)
        report = self.root / ".local/state/dotfiles/ubuntu-test/report.json"
        self.assertEqual(json.loads(report.read_text())["status"], "failed")
        self.assertTrue(json.loads(self.state.read_text())["running"])

    def test_no_replacement_or_ssh_options_are_accepted(self):
        for option in ("--yes", "--public-key"):
            with self.subTest(option=option):
                result = self.run_script("prepare", option, "unused")
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.state.exists())

    def test_non_repository_source_is_refused_without_creating_container(self):
        shutil.rmtree(self.source / ".git")

        result = self.run_script("prepare")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Git", result.stderr)
        self.assertFalse(self.state.exists())


class ComposeFixtureTests(unittest.TestCase):
    def test_compose_has_a_persistent_non_root_amd64_container_without_host_access(self):
        result = subprocess.run(
            ["docker", "compose", "-f", str(REPO / "tests/ubuntu/docker-compose.yml"),
             "config", "--format", "json"], capture_output=True, text=True, timeout=15, check=True,
        )

        service = json.loads(result.stdout)["services"]["ubuntu-dotfiles-test"]
        self.assertEqual(service["platform"], "linux/amd64")
        self.assertEqual(service["container_name"], "ubuntu-dotfiles-test")
        self.assertEqual(service["restart"], "unless-stopped")
        self.assertEqual(service["user"], "tester")
        self.assertTrue(service["init"])
        for forbidden in ("ports", "volumes", "privileged", "pid", "network_mode"):
            self.assertFalse(service.get(forbidden), forbidden)


if __name__ == "__main__":
    unittest.main()
