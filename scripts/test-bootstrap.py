#!/usr/bin/env python3
"""Bootstrap contract tests, with system and network boundaries isolated."""

import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
BOOTSTRAP = REPO / "bootstrap.sh"

# None of these commands may reach the host, even when testing the old script.
BOUNDARIES = (
    "uname", "id", "getent", "sudo", "apt-get", "locale-gen", "curl",
    "brew", "xcode-select", "softwareupdate", "chezmoi", "chown", "chsh", "bsdtar", "tar", "sha256sum",
)
DISPATCHER = r'''
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

name = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["TEST_LOG"], "a") as log:
    log.write(json.dumps({"command": name, "args": args,
                          "home": os.environ["HOME"],
                          "user": os.environ.get("USER")}) + "\n")
if name == os.environ.get("TEST_FAIL_COMMAND"):
    sys.exit(42)
if name == "uname":
    print(os.environ["TEST_OS"] if args == ["-s"] else os.environ["TEST_ARCH"])
elif name == "id":
    if args == ["-u", "tester"]:
        print("1000")
    elif args == ["-un"]:
        print("tester")
    else:
        print(os.environ["TEST_UID"])
elif name == "getent":
    print("tester:x:1000:1000:Test:" + os.environ["TEST_USER_HOME"] + ":/bin/zsh")
elif name == "sudo":
    if args == ["-v"]:
        sys.exit(0)
    if args[:3] == ["-H", "-u", "tester"]:
        args = args[3:]
    if args[:1] == ["--"]:
        args = args[1:]
    sys.exit(subprocess.call(args))
elif name == "chezmoi":
    if os.environ.get("TEST_REAL_CHEZMOI"):
        home = os.environ["HOME"]
        os.execv(os.environ["TEST_REAL_CHEZMOI"], ["chezmoi", "--config",
                 home + "/.config/chezmoi/chezmoi.toml", "--destination", home,
                 "--cache", home + "/.cache/chezmoi", "--persistent-state",
                 home + "/.local/state/chezmoi.boltdb", *args])
    if "rev-parse" in args:
        print(os.environ.get("TEST_CHECKED_OUT_BRANCH", "feat/ubuntu-support"))
    elif "get-url" in args:
        print(os.environ.get("TEST_ORIGIN", "https://example.invalid/dotfiles.git"))
elif name == "curl":
    url = next(value for value in args if value.startswith("https://"))
    destination = Path(args[args.index("-o") + 1]) if "-o" in args else None
    if url.endswith("/releases/latest"):
        content = json.dumps({"tag_name": os.environ.get("TEST_RELEASE_TAG", "v2.99.0")})
    elif url.endswith("_checksums.txt"):
        digest = os.environ["TEST_ARCHIVE_DIGEST"]
        if os.environ.get("TEST_BAD_CHECKSUM"):
            digest = "0" * 64
        content = digest + "  " + os.environ["TEST_ASSET"] + "\n"
        if os.environ.get("TEST_EMPTY_CHECKSUM"):
            content = ""
    elif url.endswith(".tar.gz"):
        shutil.copyfile(os.environ["TEST_ARCHIVE"], destination)
        sys.exit(0)
    else:
        content = ('#!/bin/sh\nset -eu\n'
                   'mkdir -p "$HOME/.local/bin"\n'
                   'cp "$TEST_DISPATCHER" "$HOME/.local/bin/chezmoi"\n'
                   'chmod +x "$HOME/.local/bin/chezmoi"\n')
    if destination is not None:
        destination.write_text(content)
    else:
        print(content)
elif name == "bsdtar":
    os.execv(os.environ["TEST_REAL_BSDTAR"], ["bsdtar", *args])
elif name == "tar":
    sys.exit("GNU tar must not be used for Ubuntu bootstrap extraction")
elif name == "sha256sum":
    os.execv(os.environ["TEST_REAL_SHASUM"], ["shasum", "-a", "256", *args])
elif name == "brew":
    if args == ["shellenv"]:
        print(":")
'''


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "commands.jsonl"
        dispatcher = self.bin / "dispatcher"
        dispatcher.write_text(f"#!{sys.executable}\n" + DISPATCHER)
        dispatcher.chmod(0o755)
        for name in BOUNDARIES:
            (self.bin / name).symlink_to(dispatcher)
        for name in ("jq",):
            executable = shutil.which(name)
            self.assertIsNotNone(executable, f"{name} is required for bootstrap verification")
            (self.bin / name).symlink_to(executable)
        self.archive = self.root / "chezmoi.tar.gz"
        binary = dispatcher.read_bytes()
        with tarfile.open(self.archive, "w:gz") as archive:
            member = tarfile.TarInfo("chezmoi")
            member.size = len(binary)
            member.mode = 0o755
            archive.addfile(member, io.BytesIO(binary))
            completion = tarfile.TarInfo("completions/chezmoi-completion.bash")
            completion.size = 0
            archive.addfile(completion, io.BytesIO())
        # Replace only the OS-release file boundary, not bootstrap logic.
        self.release = self.root / "os-release"
        self.release.write_text('ID=ubuntu\nVERSION_ID="26.04"\n')
        self.script = self.root / "bootstrap.sh"
        self.script.write_text(BOOTSTRAP.read_text().replace(
            "/etc/os-release", str(self.release)
        ))
        self.env = {
            "HOME": str(self.home), "USER": "tester", "LOGNAME": "tester",
            "PATH": f"{self.home}/.local/bin:{self.bin}:/usr/bin:/bin",
            "TEST_OS": "Linux", "TEST_ARCH": "x86_64", "TEST_UID": "1000",
            "TEST_LOG": str(self.log), "TEST_USER_HOME": str(self.home),
            "TEST_DISPATCHER": str(dispatcher), "LC_ALL": "C",
            "TEST_ARCHIVE": str(self.archive),
            "TEST_ARCHIVE_DIGEST": hashlib.sha256(self.archive.read_bytes()).hexdigest(),
            "TEST_ASSET": "chezmoi_2.99.0_linux-glibc_amd64.tar.gz",
            "TEST_REAL_BSDTAR": shutil.which("bsdtar"),
            "TEST_REAL_SHASUM": shutil.which("shasum"),
        }

    def run_bootstrap(self, *args, piped=False):
        command = ["/bin/bash", str(self.script), *args]
        content = None
        if piped:
            command = ["/bin/bash", "-s", "--", *args]
            content = self.script.read_text()
        return subprocess.run(
            command, input=content, env=self.env,
            text=True, capture_output=True, timeout=15,
        )

    def commands(self):
        if not self.log.exists():
            return []
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def assert_no_provisioning(self):
        mutations = {"sudo", "apt-get", "brew", "curl", "chezmoi", "softwareupdate"}
        self.assertFalse([c for c in self.commands() if c["command"] in mutations])

    def test_minimal_ubuntu_installs_prerequisites_before_initialization(self):
        (self.bin / "chezmoi").unlink()
        result = self.run_bootstrap()
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = self.commands()
        installs = [c for c in commands if c["command"] == "apt-get"
                    and "install" in c["args"]]
        self.assertTrue(installs, "minimal Ubuntu did not install prerequisites")
        packages = installs[0]["args"]
        for package in ("ca-certificates", "curl", "git", "gnupg", "libarchive-tools", "7zip", "locales", "jq", "zsh"):
            self.assertIn(package, packages)
        init = next(c for c in commands if c["command"] == "chezmoi")
        self.assertLess(commands.index(installs[0]), commands.index(init))
        self.assertEqual(init["home"], str(self.home))
        self.assertNotIn("--keep-going", init["args"])
        self.assertFalse([c for c in commands if c["command"] in
                          {"brew", "xcode-select", "softwareupdate"}])

    def test_unsupported_os_is_rejected_before_changes(self):
        self.env["TEST_OS"] = "FreeBSD"
        result = self.run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unsupported", result.stderr)
        self.assert_no_provisioning()

    def test_unsupported_ubuntu_release_is_rejected_before_changes(self):
        self.release.write_text('ID=ubuntu\nVERSION_ID="24.04"\n')
        result = self.run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("26.04", result.stderr)
        self.assert_no_provisioning()

    def test_unsupported_architecture_is_rejected_before_changes(self):
        self.env["TEST_ARCH"] = "aarch64"
        result = self.run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("AMD64", result.stderr)
        self.assert_no_provisioning()

    def test_root_requires_explicit_non_root_user(self):
        self.env["TEST_UID"] = "0"
        result = self.run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("--user", result.stderr)
        self.assert_no_provisioning()

    def test_missing_elevation_fails_before_installing(self):
        self.env["TEST_FAIL_COMMAND"] = "sudo"
        result = self.run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("sudo", result.stderr)
        self.assertFalse([c for c in self.commands() if c["command"] == "apt-get"])

    def test_help_documents_every_bootstrap_option_without_provisioning(self):
        result = self.run_bootstrap("--help", piped=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        for option in ("--repo", "--branch", "--source", "--user", "--profile"):
            self.assertIn(option, result.stdout)
        self.assert_no_provisioning()

    def test_missing_option_values_are_rejected_before_changes(self):
        for option in ("--repo", "--branch", "--source", "--user", "--profile"):
            with self.subTest(option=option):
                result = self.run_bootstrap(option)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("requires a value", result.stderr)
                self.assert_no_provisioning()

    def test_explicit_branch_and_repo_are_honored_in_piped_invocation(self):
        repo = "https://example.invalid/dotfiles.git"
        result = self.run_bootstrap("--repo", repo, "--branch", "feat/ubuntu-support", piped=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = [c for c in self.commands() if c["command"] == "chezmoi"]
        init = next(c for c in commands if "init" in c["args"])
        self.assertIn(repo, init["args"])
        self.assertEqual(init["args"][init["args"].index("--branch") + 1], "feat/ubuntu-support")
        self.assertIn("apply", commands[-1]["args"])
        self.assertFalse(any("main" in c["args"] for c in commands))

    def test_branch_mismatch_refuses_apply_without_falling_back(self):
        self.env["TEST_CHECKED_OUT_BRANCH"] = "main"
        result = self.run_bootstrap("--branch", "feat/ubuntu-support")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Requested branch", result.stderr)
        self.assertFalse([c for c in self.commands() if "apply" in c["args"]
                          or "--apply" in c["args"]])

    def test_existing_remote_mismatch_refuses_apply(self):
        self.env["TEST_ORIGIN"] = "https://example.invalid/other.git"
        result = self.run_bootstrap("--repo", "https://example.invalid/dotfiles.git")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("repository", result.stderr)
        self.assertFalse([c for c in self.commands() if "apply" in c["args"]])

    def test_conflicting_local_and_remote_options_fail_before_changes(self):
        for flag, value in (("--repo", "https://example.invalid/dotfiles.git"),
                            ("--branch", "feat/ubuntu-support")):
            with self.subTest(flag=flag):
                result = self.run_bootstrap("--source", str(self.root), flag, value)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("conflict", result.stderr)
                self.assert_no_provisioning()

    def test_local_changed_source_is_applied_without_a_remote(self):
        real_chezmoi = shutil.which("chezmoi")
        self.assertIsNotNone(real_chezmoi, "install chezmoi to run local-source integration tests")
        self.env["TEST_REAL_CHEZMOI"] = real_chezmoi
        source = self.root / "changed source"
        source.mkdir()
        (source / "dot_marker").write_text("uncommitted source content\n")
        result = self.run_bootstrap("--source", str(source), piped=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / ".marker").read_text(), "uncommitted source content\n")
        commands = [c for c in self.commands() if c["command"] == "chezmoi"]
        self.assertTrue(commands)
        self.assertFalse(any("petronetto" in c["args"] for c in commands))
        self.assertFalse(any("--branch" in c["args"] for c in commands))

    def test_test_profile_is_persisted_and_survives_rerun_without_environment(self):
        real_chezmoi = shutil.which("chezmoi")
        self.assertIsNotNone(real_chezmoi)
        self.env["TEST_REAL_CHEZMOI"] = real_chezmoi
        source = self.root / "profile source"
        source.mkdir()
        shutil.copyfile(REPO / ".chezmoi.toml.tmpl", source / ".chezmoi.toml.tmpl")
        (source / "dot_profile.tmpl").write_text('{{ .profile }}:{{ .git_email }}')
        config = self.home / ".config/chezmoi/chezmoi.toml"
        config.parent.mkdir(parents=True)
        config.write_text('[data]\ngit_email = "fixture@example.invalid"\n')

        first = self.run_bootstrap("--source", str(source), "--profile", "test-container")
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual((self.home / ".profile").read_text(),
                         "test-container:fixture@example.invalid")
        self.assertIn('profile = "test-container"', config.read_text())
        second = self.run_bootstrap("--source", str(source))
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual((self.home / ".profile").read_text(),
                         "test-container:fixture@example.invalid")

    def test_invalid_profile_fails_before_changes(self):
        result = self.run_bootstrap("--profile", "unknown")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("workstation or test-container", result.stderr)
        self.assert_no_provisioning()

    def test_private_lookup_is_guarded_before_template_evaluation(self):
        real_chezmoi = shutil.which("chezmoi")
        self.assertIsNotNone(real_chezmoi)
        shell = self.bin / "sh"
        shell.write_text(f'#!{sys.executable}\nimport os\nfrom pathlib import Path\n'
                         'Path(os.environ["TEST_LOG"]).write_text("lookup attempted")\n'
                         'print("fixture-head")\n')
        shell.chmod(0o755)
        template = (REPO / ".chezmoiscripts/run_onchange_before_sync.sh.tmpl").read_text()
        for profile in ("test-container", "workstation", None):
            with self.subTest(profile=profile):
                self.log.write_text("")
                data = {} if profile is None else {"profile": profile}
                result = subprocess.run(
                    [real_chezmoi, "--config", str(self.root / "absent.toml"),
                     "--source", str(self.root), "--destination", str(self.home),
                     "execute-template", "--override-data", json.dumps(data)],
                    input=template, env=self.env, text=True, capture_output=True, timeout=15,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                if profile == "test-container":
                    self.assertEqual(self.log.read_text(), "")
                    self.assertEqual(result.stdout.strip(), "")
                else:
                    self.assertEqual(self.log.read_text(), "lookup attempted")
                    self.assertIn("fixture-head", result.stdout)
                    self.assertIn("scripts/sync-private-dotfiles", result.stdout)

    def test_missing_source_fails_before_changes(self):
        result = self.run_bootstrap("--source", str(self.root / "absent"))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("source directory", result.stderr)
        self.assert_no_provisioning()

    def test_root_provisions_selected_home_as_target_user(self):
        self.env.update(TEST_UID="0", HOME=str(self.root), USER="root")
        (self.bin / "chezmoi").unlink()
        result = self.run_bootstrap("--user", "tester")
        self.assertEqual(result.returncode, 0, result.stderr)
        init = next(c for c in self.commands() if c["command"] == "chezmoi")
        self.assertEqual(init["home"], str(self.home))
        self.assertEqual(init["user"], "tester")
        self.assertTrue((self.home / ".local/bin/chezmoi").exists())
        self.assertFalse((self.root / ".local/bin/chezmoi").exists())

    def test_root_cannot_select_root_account(self):
        self.env["TEST_UID"] = "0"
        result = self.run_bootstrap("--user", "root")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("non-root", result.stderr)
        self.assert_no_provisioning()

    def test_normal_user_cannot_select_another_account(self):
        result = self.run_bootstrap("--user", "someone-else")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("different --user", result.stderr)
        self.assert_no_provisioning()

    def test_required_ubuntu_failures_propagate_with_stage(self):
        for command, stage in (("apt-get", "prerequisite"),
                               ("locale-gen", "locale"),
                               ("chezmoi", "initialization")):
            with self.subTest(command=command):
                self.env["TEST_FAIL_COMMAND"] = command
                self.log.write_text("")
                result = self.run_bootstrap()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(stage, result.stderr)
                self.assertNotIn("Bootstrap complete", result.stdout)

    def test_required_chezmoi_download_failure_stops_initialization(self):
        (self.bin / "chezmoi").unlink()
        self.env["TEST_FAIL_COMMAND"] = "curl"
        result = self.run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("chezmoi download/install", result.stderr)
        self.assertFalse([c for c in self.commands() if c["command"] == "chezmoi"])

    def test_ubuntu_installs_the_official_checksummed_release_with_bsdtar(self):
        (self.bin / "chezmoi").unlink()

        result = self.run_bootstrap()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.home / ".local/bin/chezmoi").is_file())
        downloads = [argument for call in self.commands() if call["command"] == "curl"
                     for argument in call["args"] if argument.startswith("https://")]
        self.assertIn("https://api.github.com/repos/twpayne/chezmoi/releases/latest", downloads)
        self.assertIn("https://github.com/twpayne/chezmoi/releases/download/v2.99.0/" + self.env["TEST_ASSET"], downloads)
        self.assertTrue(any(call["command"] == "bsdtar" for call in self.commands()))
        self.assertFalse(any(call["command"] == "tar" for call in self.commands()))
        record = json.loads((self.home / ".local/state/dotfiles/bootstrap-chezmoi.json").read_text())
        self.assertEqual(record["version"], "2.99.0")
        self.assertEqual(record["sha256"], self.env["TEST_ARCHIVE_DIGEST"])
        self.assertEqual(record["verification"], "release-sha256")

    def test_ubuntu_rejects_bad_or_missing_release_checksums_before_installation(self):
        (self.bin / "chezmoi").unlink()
        for setting in ("TEST_BAD_CHECKSUM", "TEST_EMPTY_CHECKSUM"):
            with self.subTest(setting=setting):
                self.env[setting] = "1"
                self.log.write_text("")

                result = self.run_bootstrap()

                self.assertNotEqual(result.returncode, 0)
                self.assertIn("chezmoi download/install", result.stderr)
                self.assertFalse((self.home / ".local/bin/chezmoi").exists())
                self.assertFalse(any(call["command"] in ("bsdtar", "chezmoi") for call in self.commands()))
                del self.env[setting]

    def test_ubuntu_rejects_invalid_release_tags_before_asset_download(self):
        (self.bin / "chezmoi").unlink()
        self.env["TEST_RELEASE_TAG"] = "../../untrusted"

        result = self.run_bootstrap()

        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.home / ".local/bin/chezmoi").exists())
        downloads = [call for call in self.commands() if call["command"] == "curl"]
        self.assertEqual(len(downloads), 1)

    def test_ubuntu_extraction_failure_does_not_install_or_initialize_chezmoi(self):
        (self.bin / "chezmoi").unlink()
        self.env["TEST_FAIL_COMMAND"] = "bsdtar"

        result = self.run_bootstrap()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("chezmoi download/install", result.stderr)
        self.assertFalse((self.home / ".local/bin/chezmoi").exists())
        self.assertFalse(any(call["command"] == "chezmoi" for call in self.commands()))

    def test_macos_retains_existing_init_and_does_not_install_ubuntu_tools(self):
        self.env["TEST_OS"] = "Darwin"
        result = self.run_bootstrap()
        self.assertEqual(result.returncode, 0, result.stderr)
        init = next(c for c in self.commands() if c["command"] == "chezmoi")
        self.assertEqual(init["args"], ["init", "--apply", "--keep-going", "petronetto"])
        self.assertFalse([c for c in self.commands() if c["command"] in
                          {"apt-get", "locale-gen", "curl"}])

    def test_macos_keeps_homebrew_workflow_and_reports_required_failure(self):
        self.env.update(TEST_OS="Darwin", TEST_FAIL_COMMAND="brew")
        (self.bin / "chezmoi").unlink()
        result = self.run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("chezmoi", result.stderr)
        self.assertFalse([c for c in self.commands() if c["command"] == "apt-get"])


if __name__ == "__main__":
    unittest.main()
