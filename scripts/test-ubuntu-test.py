#!/usr/bin/env python3
"""Fixture tests for the retained ubuntu-test container lifecycle.

These tests exercise the source-snapshot allowlist, working-tree digest,
public-key-only SSH input, and existing-container preservation rules through a
fake docker/ssh boundary. They never touch the host Docker daemon, the host
SSH agent, or real container state.
"""

import json
import os
import subprocess
import tarfile
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / "scripts/ubuntu-test"

BOUNDARY = r'''
import json
import os
from pathlib import Path
import sys

name = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["TEST_LOG"], "a") as log:
    log.write(json.dumps({"command": name, "args": args}) + "\n")

if name == "docker":
    if "ps" in args:
        sys.stdout.write(os.environ.get("TEST_DOCKER_PS", ""))
    elif "image" in args and "inspect" in args:
        print(os.environ.get("TEST_IMAGE_DIGEST", "fixture-image-digest"))
    elif "exec" in args and "cat" in args:
        print(os.environ.get("TEST_DOCKER_FINGERPRINT", "fixture-fingerprint"))
    elif "compose" in args and "config" in args:
        print("name: ubuntu-dotfiles-test")
    elif "logs" in args:
        print("fixture-sshd-log")
    sys.exit(0)
if name == "nc":
    sys.exit(0 if os.environ.get("TEST_PORT_IN_USE") else 1)
if name == "ssh-keygen":
    print("256 SHA256:fixture-key-fingerprint tester (ED25519)")
    sys.exit(0)
print("blocked external command: " + name, file=sys.stderr)
sys.exit(99)
'''


class UbuntuTestFixtureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "commands.jsonl"
        self.env = {
            "HOME": str(self.root),
            "PATH": str(self.bin) + os.pathsep + os.environ.get("PATH", ""),
            "TEST_LOG": str(self.log),
        }
        for command in ("docker", "nc", "ssh-keygen"):
            path = self.bin / command
            path.write_text("#!/usr/bin/env python3\n" + BOUNDARY)
            path.chmod(0o755)

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    def make_source(self) -> Path:
        """A hermetic stand-in for the repo source under test."""
        src = self.root / "src"
        (src / "dot_config/zsh").mkdir(parents=True)
        (src / "dot_config/zsh/dot_zshrc").write_text("fixture-zshrc\n")
        (src / ".chezmoidata").mkdir()
        (src / ".chezmoidata/ubuntu.yaml").write_text("ubuntu: {}\n")
        (src / "scripts").mkdir()
        (src / "scripts/install-ubuntu-packages").write_text("#!/usr/bin/env zsh\n")
        (src / ".git").mkdir()
        (src / ".git/HEAD").write_text("ref: fixture\n")
        (src / "untracked-fixture.bin").write_bytes(b"binary")
        (src / "key.txt.age").write_text("age-secret\n")
        (src / "private").mkdir()
        (src / "private/secret.txt").write_text("private-data\n")
        return src

    def write_key(self, name="fixture-key.pub") -> Path:
        key = self.root / name
        key.write_text("ssh-ed25519 AAAA fixture-public-key comment\n")
        return key

    def state_dir(self) -> Path:
        return self.root / ".local/state/dotfiles/ubuntu-test"

    def write_state_fingerprint(self, value: str):
        directory = self.state_dir()
        directory.mkdir(parents=True, exist_ok=True)
        (directory / "fingerprint").write_text(value + "\n")

    def manifest(self) -> dict:
        return json.loads((self.state_dir() / "manifest.json").read_text())

    def commands(self):
        if not self.log.exists():
            return []
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def run_script(self, *args, env=None):
        return subprocess.run(
            ["zsh", str(SCRIPT), *args],
            capture_output=True, text=True, timeout=30,
            env={**self.env, **(env or {})},
        )

    # ------------------------------------------------------------------
    # Source snapshot: allowlist and working-tree digest
    # ------------------------------------------------------------------

    def test_snapshot_includes_tracked_source_and_new_files_only(self):
        """Allowlisted snapshot copies tracked public source plus new files."""
        src = self.make_source()
        result = self.run_script("prepare", "--source", str(src),
                                 "--public-key", str(self.write_key()))
        self.assertEqual(result.returncode, 0, result.stderr)
        manifest = self.manifest()
        self.assertIn("dot_config/zsh/dot_zshrc", manifest["files"])
        self.assertIn("scripts/install-ubuntu-packages", manifest["files"])
        self.assertIn(".chezmoidata/ubuntu.yaml", manifest["files"])
        self.assertRegex(result.stdout, r"digest: ?[0-9a-f]{8,}")

    def test_snapshot_excludes_private_ignored_and_git_paths(self):
        """The snapshot must exclude .git, private trees, and ignored files."""
        src = self.make_source()
        result = self.run_script("prepare", "--source", str(src),
                                 "--public-key", str(self.write_key()))
        self.assertEqual(result.returncode, 0, result.stderr)
        files = "\n".join(self.manifest()["files"])
        for forbidden in (".git", "private/secret.txt", "key.txt.age",
                          "untracked-fixture.bin", "docs/", "tests/"):
            self.assertNotIn(forbidden, files)
        excluded = "\n".join(self.manifest()["excluded"])
        for category in ("git", "private", "secrets", "caches"):
            self.assertIn(category, excluded)

    def test_uncommitted_changes_are_included_and_digested(self):
        """Working-tree changes flow into the snapshot under a real digest."""
        src = self.make_source()
        (src / "dot_config/zsh/dot_zshrc").write_text("uncommitted fixture change\n")
        result = self.run_script("prepare", "--source", str(src),
                                 "--public-key", str(self.write_key()))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertRegex(result.stdout, r"digest: ?[0-9a-f]{8,}")
        with tarfile.open(self.state_dir() / "source-snapshot.tar") as tar:
            content = tar.extractfile("dot_config/zsh/dot_zshrc").read().decode()
        self.assertIn("uncommitted fixture change", content)

    # ------------------------------------------------------------------
    # Public-key-only SSH input
    # ------------------------------------------------------------------

    def test_public_key_is_the_only_credential_input(self):
        """Only the explicit public key file reaches the container."""
        key = self.write_key()
        result = self.run_script("prepare", "--public-key", str(key))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("SHA256:fixture-key-fingerprint", result.stdout)
        self.assertIn("authorized_keys", result.stdout)
        self.assertNotIn("PRIVATE KEY", result.stdout + result.stderr)
        copies = [c for c in self.commands()
                  if c["command"] == "docker" and "cp" in c["args"]]
        self.assertEqual(len(copies), 1, self.commands())
        self.assertIn(str(key), " ".join(copies[0]["args"]))

    def test_missing_public_key_is_a_required_failure(self):
        result = self.run_script("prepare")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("public key", result.stderr.lower())

    # ------------------------------------------------------------------
    # Existing-container preservation
    # ------------------------------------------------------------------

    def test_matching_existing_container_is_reused_not_rebuilt(self):
        """A matching retained container is reused, never recreated."""
        self.write_state_fingerprint("fixture-fingerprint")
        self.env["TEST_DOCKER_PS"] = (
            "ubuntu-dotfiles-test\tubuntu-dotfiles-test:26.04\trunning\n")
        self.env["TEST_DOCKER_FINGERPRINT"] = "fixture-fingerprint"
        result = self.run_script("start")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("reusing", result.stdout.lower())
        self.assertNotIn("replaced", result.stdout.lower())
        self.assertFalse(any(c["command"] == "docker" and "rm" in c["args"]
                             for c in self.commands()))

    def test_mismatched_container_fingerprint_requires_confirmation(self):
        """A source/image mismatch refuses a silent replacement."""
        self.write_state_fingerprint("current-fingerprint")
        self.env["TEST_DOCKER_PS"] = (
            "ubuntu-dotfiles-test\tubuntu-dotfiles-test:26.04\trunning\n")
        self.env["TEST_DOCKER_FINGERPRINT"] = "stale-fingerprint"
        result = self.run_script("start")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("fingerprint", result.stderr.lower())
        self.assertNotIn("replaced", result.stdout.lower())
        self.assertFalse(any(c["command"] == "docker" and "rm" in c["args"]
                             for c in self.commands()))

    def test_occupied_port_reports_without_public_bind(self):
        """An occupied host port is a required failure, never a rebinding."""
        self.env["TEST_PORT_IN_USE"] = "1"
        result = self.run_script("prepare", "--public-key", "fixture.pub")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("port", result.stderr.lower())
        self.assertNotIn("0.0.0.0", result.stdout + result.stderr)


class ComposeFixtureTests(unittest.TestCase):
    """Static contract checks for tests/ubuntu (4.2/4.3 fixture boundaries).

    The retained sandbox itself is exercised on the real Docker host; these
    checks run everywhere and fail fast when the fixture gains host access,
    secrets, or a public bind address.
    """

    def setUp(self):
        self.compose = (REPO / "tests/ubuntu/docker-compose.yml").read_text()
        self.dockerfile = (REPO / "tests/ubuntu/Dockerfile").read_text()
        self.entrypoint = (REPO / "tests/ubuntu/entrypoint.sh").read_text()

    def test_compose_pins_architecture_name_and_localhost_binding(self):
        self.assertIn("platform: linux/amd64", self.compose)
        self.assertIn("container_name: ubuntu-dotfiles-test", self.compose)
        self.assertIn('"127.0.0.1:2222:22"', self.compose)
        self.assertNotIn("0.0.0.0", self.compose)

    def test_compose_uses_init_and_unless_stopped_restart(self):
        self.assertIn("init: true", self.compose)
        self.assertIn("restart: unless-stopped", self.compose)

    def test_compose_has_no_privileged_host_or_docker_access(self):
        self.assertNotIn("privileged", self.compose)
        self.assertNotIn("pid:", self.compose)
        self.assertNotIn("network_mode", self.compose)
        self.assertNotIn("volumes:", self.compose)
        self.assertNotIn("docker.sock", self.compose)
        self.assertNotIn("/home/", self.compose)

    def test_dockerfile_creates_sudo_zsh_tester_without_passwordless_sudo(self):
        self.assertIn("useradd -m -s /bin/zsh tester", self.dockerfile)
        self.assertIn("usermod -aG sudo tester", self.dockerfile)
        self.assertNotIn("NOPASSWD", self.dockerfile)
        self.assertNotIn("password", self.dockerfile.lower())

    def test_entrypoint_generates_per_container_keys_and_disables_access(self):
        self.assertIn("ssh-keygen -A", self.entrypoint)
        self.assertIn("PasswordAuthentication no", self.entrypoint)
        self.assertIn("PermitRootLogin no", self.entrypoint)
        self.assertIn("AllowAgentForwarding no", self.entrypoint)
        self.assertIn("exec /usr/sbin/sshd -D", self.entrypoint)


if __name__ == "__main__":
    unittest.main()
