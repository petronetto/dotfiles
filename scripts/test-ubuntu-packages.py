#!/usr/bin/env python3
"""Validate rendered Ubuntu installer inputs without using host package tools."""

import copy
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
INSTALLER = REPO / "scripts/install-ubuntu-packages"
REQUIRED_COMMANDS = {
    "zsh", "git", "curl", "chezmoi", "mise", "node", "npm", "npx", "starship",
    "herdr", "pi", "ghostty", "1password", "op", "brave-browser", "obsidian",
    "zed", "todoist", "td", "docker", "docker compose", "docker buildx", "rg", "fd", "bat",
    "fzf", "jq", "zoxide", "lsd", "delta", "ast-grep", "atuin", "tmux", "nvim",
}


INSTALL_BOUNDARY = r'''
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["TEST_LOG"], "a") as log:
    log.write(json.dumps({"command": name, "args": args}) + "\n")
if name == os.environ.get("TEST_FAIL_COMMAND"):
    sys.exit(42)
if name == "uname":
    print(os.environ.get("TEST_OS", "Linux") if args == ["-s"] else "x86_64")
elif name == "tar":
    os.execv(os.environ["TEST_REAL_TAR"], ["tar", *args])
elif name == "sudo":
    assert args[0] == "--"
    assert args[1] in ("install", "apt-get", "env")
    sys.exit(subprocess.call(args[1:]))
elif name == "curl":
    destination = Path(args[args.index("-o") + 1])
    shutil.copyfile(os.environ["TEST_PAYLOAD"], destination)
elif name == "gpg":
    if "--dearmor" in args:
        Path(args[args.index("--output") + 1]).write_bytes(b"fixture-keyring")
    else:
        print("fpr:::::::::" + os.environ.get("TEST_KEY_FINGERPRINT", "3FEF9748469ADBE15DA7CA80AC2D62742012EA22") + ":")
elif name == "apt-get" and "install" in args:
    mapping = {"fd-find": "fdfind", "bat": "batcat", "ripgrep": "rg", "1password-cli": "op",
               "docker-ce": "docker", "docker-ce-cli": "docker"}
    for package in args[args.index("install") + 1:]:
        if package.startswith("-"):
            continue
        if package.endswith(".deb"):
            package = "obsidian"
            app = Path(os.environ["TEST_ROOT"], "obsidian-app")
            app.write_text("#!/bin/sh\nexit 0\n")
            app.chmod(0o755)
            if not os.environ.get("TEST_OMIT_OBSIDIAN_CLI"):
                cli = Path(os.environ["TEST_ROOT"], "obsidian-cli")
                cli.write_text("#!/bin/sh\necho official-cli\n")
                cli.chmod(0o755)
        binary = Path(os.environ["TEST_ROOT"], "bin", mapping.get(package, package))
        if mapping.get(package) == "docker":
            if not binary.exists():
                binary.symlink_to(Path(os.environ["TEST_ROOT"], "bin/dispatcher"))
            continue
        if not binary.is_symlink():
            binary.write_text("#!/bin/sh\necho fixture-version\n")
            binary.chmod(0o755)
        if package == "1password" and not os.environ.get("TEST_OMIT_SIGNING_HELPER"):
            helper = Path(os.environ["TEST_ROOT"], "op-ssh-sign")
            helper.write_text("#!/bin/sh\nexit 0\n")
            helper.chmod(0o755)
elif name == "fc-match":
    print("DejaVu Sans" if os.environ.get("TEST_FONT_FALLBACK") else args[-1])
elif name == "7z":
    destination = next(arg[2:] for arg in args if arg.startswith("-o"))
    shutil.copytree(os.environ["TEST_TODOIST_APP"], destination, dirs_exist_ok=True)
elif name == "ldd":
    print("libfixture => not found" if os.environ.get("TEST_MISSING_LIBRARY") else "libfixture => /usr/lib/libfixture")
elif name == "docker":
    if args[0] == os.environ.get("TEST_MISSING_DOCKER_PLUGIN"):
        sys.exit(42)
    print("fixture-version")
elif name == "dpkg-query":
    if "${db:Status-Status}" in args[2]:
        if args[-1] == os.environ.get("TEST_DOCKER_CONFLICT"):
            print("installed")
            sys.exit(0)
        sys.exit(1)
    for package in args[3:]:
        print(package + "=fixture-version")
elif name == "mise":
    if "npm" in args and "prefix" in args:
        Path(os.environ["HOME"], ".npmrc").write_text("prefix=" + args[-1] + "\n")
    elif "npm" in args and "install" in args:
        package, version = args[-1].rsplit("@", 1)
        package_dir = Path(os.environ["HOME"], ".local/lib/node_modules", package)
        package_dir.mkdir(parents=True)
        (package_dir / "package.json").write_text(json.dumps({"version": version}))
        binary = Path(os.environ["HOME"], ".local/bin", "pi" if "pi-coding-agent" in package else "td")
        binary.write_text("#!/bin/sh\necho " + version + "\n")
        binary.chmod(0o755)
    elif "node" in args and "--version" in args:
        print("v24.22.1")
elif name == "install":
    destination = Path(args[-1])
    if str(destination).startswith(("/etc/", "/usr/")):
        destination = Path(os.environ["TEST_ROOT"]) / "system" / str(destination).lstrip("/")
    assert str(destination).startswith(os.environ["TEST_ROOT"]), destination
    if "-d" in args:
        destination.mkdir(parents=True, exist_ok=True)
    else:
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(args[-2], destination)
        destination.chmod(int(args[args.index("-m") + 1], 8))
'''


class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        data = self.root / "source/.chezmoidata"
        data.mkdir(parents=True)
        self.assertTrue((REPO / ".chezmoidata/ubuntu.yaml").is_file(), "Ubuntu catalog is missing")
        shutil.copyfile(REPO / ".chezmoidata/ubuntu.yaml", data / "ubuntu.yaml")
        chezmoi = shutil.which("chezmoi")
        self.assertIsNotNone(chezmoi, "chezmoi is required for template tests")
        result = subprocess.run(
            [chezmoi, "--config", str(self.root / "absent.toml"),
             "--source", str(data.parent), "--destination", str(self.root / "home"),
             "execute-template", "{{ .ubuntu | toJson }}"],
            env={"PATH": os.environ["PATH"], "HOME": str(self.root)},
            text=True, capture_output=True, timeout=15,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.catalog = json.loads(result.stdout)

    def validate(self, catalog):
        return subprocess.run(
            ["zsh", str(INSTALLER), "--check-catalog"], input=json.dumps(catalog),
            text=True, capture_output=True, timeout=15,
        )

    def installer_environment(self, payload=b"#!/bin/sh\necho fixture\n"):
        home = self.root / "target home"
        home.mkdir(exist_ok=True)
        bin_dir = self.root / "bin"
        bin_dir.mkdir(exist_ok=True)
        asset = self.root / "payload"
        asset.write_bytes(payload)
        dispatcher = bin_dir / "dispatcher"
        dispatcher.write_text(f"#!{sys.executable}\n" + INSTALL_BOUNDARY)
        dispatcher.chmod(0o755)
        (bin_dir / "jq").symlink_to(shutil.which("jq"))
        for command in ("uname", "sudo", "apt-get", "curl", "install", "gpg", "brew", "dpkg-query", "ldd", "tar", "7z", "fc-cache", "fc-match"):
            path = bin_dir / command
            if not path.exists():
                path.symlink_to(dispatcher)
        return {
            "HOME": str(home), "PATH": f"{bin_dir}:/usr/bin:/bin:/usr/sbin:/sbin",
            "TEST_ROOT": str(self.root), "TEST_PAYLOAD": str(asset),
            "TEST_LOG": str(self.root / "commands.jsonl"), "LC_ALL": "C",
            "TEST_REAL_TAR": shutil.which("tar"),
        }

    def run_installer(self, env, *options):
        script = self.root / "installer.zsh"
        content = INSTALLER.read_text()
        for original, fixture in (("/.dockerenv", "container-marker"),
                                  ("/usr/sbin/policy-rc.d", "policy-rc.d"),
                                  ("/opt/1Password/op-ssh-sign", "op-ssh-sign"),
                                  ("/opt/Obsidian/obsidian-cli", "obsidian-cli"),
                                  ("/opt/Obsidian/obsidian", "obsidian-app"),
                                  ("/dev/tty", "consent")):
            content = content.replace(original, str(self.root / fixture))
        script.write_text(content)
        return subprocess.run(
            ["zsh", str(script), *options], input=json.dumps(self.catalog),
            env=env, text=True, capture_output=True, timeout=15,
        )

    def install_tool(self, tool_id, env, *options):
        return self.run_installer(env, "--tool", tool_id, *options)

    def fixture_tool(self, tool_id, payload):
        tool = next(t for t in self.catalog["tools"] if t["id"] == tool_id)
        tool["sha256"] = hashlib.sha256(payload).hexdigest()
        tool["version"] = f"fixture-{tool_id}"
        return tool

    def test_fonts_install_verified_files_and_reject_fontconfig_fallback(self):
        archive = io.BytesIO()
        with tarfile.open(fileobj=archive, mode="w:xz") as tar:
            entry = tarfile.TarInfo("fixture.ttf")
            entry.size = 4
            tar.addfile(entry, io.BytesIO(b"font"))
        env = self.installer_environment(archive.getvalue())
        for font in self.catalog["fonts"]:
            font["sha256"] = hashlib.sha256(archive.getvalue()).hexdigest()
        result = self.run_installer(env, "--fonts")
        self.assertEqual(result.returncode, 0, result.stderr)
        fonts = Path(env["HOME"]) / ".local/share/fonts/NerdFonts"
        self.assertEqual(len(list(fonts.rglob("fixture.ttf"))), 2)
        state = json.loads((Path(env["HOME"]) / ".local/state/dotfiles/ubuntu-packages.json").read_text())
        self.assertEqual(state["font:JetBrainsMono"]["verification"], "sha256")
        self.assertIn("nerd-fonts", state["font:JetBrainsMono"]["provenance"])
        env["TEST_FONT_FALLBACK"] = "1"
        result = self.run_installer(env, "--fonts")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not discoverable", result.stderr)

    def test_managed_inventory_excludes_test_docs_and_macos_mise_files(self):
        source, _ = self.prepare_lifecycle_fixture()
        shutil.copyfile(REPO / ".chezmoiignore", source / ".chezmoiignore")
        for name in ("tests/ubuntu/Dockerfile", "docs/ubuntu.md"):
            path = source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("repo-only fixture\n")
        for platform in ("darwin", "linux"):
            with self.subTest(platform=platform):
                result = subprocess.run(
                    [*self.lifecycle_command(source, platform), "managed", "--format", "json"],
                    env={"HOME": str(self.root / "home"), "PATH": os.environ["PATH"]},
                    text=True, capture_output=True, timeout=15,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                inventory = result.stdout.splitlines()
                self.assertFalse(any(p.startswith(("tests", "docs", "scripts")) for p in inventory))
                self.assertEqual(".config/mise/config.toml" in inventory, platform == "linux")

    def test_docker_decline_has_no_package_service_or_access_changes(self):
        env = self.installer_environment()
        (self.root / "consent").write_text("n\n")
        result = self.install_tool("docker", env)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("declined", result.stderr)
        commands = [json.loads(line) for line in Path(env["TEST_LOG"]).read_text().splitlines()]
        self.assertFalse(any(c["command"] in ("sudo", "apt-get", "curl") for c in commands))

    def test_docker_test_profile_requires_service_suppression_policy(self):
        env = self.installer_environment()
        result = self.install_tool("docker", env, "--profile", "test-container")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("explicit service policy", result.stderr)

    def test_docker_installs_engine_and_plugins_without_daemon_or_group_actions(self):
        env = self.installer_environment()
        (self.root / "container-marker").touch()
        policy = self.root / "policy-rc.d"
        policy.write_text("#!/bin/sh\nexit 101\n")
        policy.chmod(0o755)
        env["TEST_KEY_FINGERPRINT"] = "9DC858229FC7DD38854AE2D88D81803C0EBFCD88"
        result = self.install_tool("docker", env, "--profile", "test-container")
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = [json.loads(line) for line in Path(env["TEST_LOG"]).read_text().splitlines()]
        packages = next(c["args"] for c in commands if c["command"] == "apt-get" and "install" in c["args"])
        self.assertIn("docker-ce", packages)
        self.assertIn("docker-compose-plugin", packages)
        self.assertNotIn("docker-desktop", packages)
        self.assertFalse(any(c["command"] in ("usermod", "groupadd", "systemctl") for c in commands))
        env["TEST_MISSING_DOCKER_PLUGIN"] = "compose"
        result = self.install_tool("docker", env, "--profile", "test-container")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("docker", result.stderr)

    def test_docker_conflicting_packages_are_refused_not_removed(self):
        env = self.installer_environment()
        env["TEST_DOCKER_CONFLICT"] = "containerd"
        result = self.install_tool("docker", env, "--profile", "test-container")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("conflicting package containerd", result.stderr)
        commands = [json.loads(line) for line in Path(env["TEST_LOG"]).read_text().splitlines()]
        self.assertFalse(any(c["command"] in ("sudo", "apt-get", "curl") for c in commands))

    def test_todoist_uses_stable_extracted_launcher_without_vendor_sandbox_bypass(self):
        env = self.installer_environment()
        app = self.root / "todoist-source"
        app.mkdir()
        (app / "todoist.desktop").write_text("[Desktop Entry]\nX-AppImage-Version=9.31.0\nExec=AppRun --no-sandbox %U\n")
        (app / "AppRun").write_text("#!/bin/sh\nexit 99\n")
        binary = app / "todoist"
        binary.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
        binary.chmod(0o755)
        env["TEST_TODOIST_APP"] = str(app)
        for _ in range(2):
            result = self.install_tool("todoist", env)
            self.assertEqual(result.returncode, 0, result.stderr)
        launcher = Path(env["HOME"]) / ".local/bin/todoist"
        self.assertTrue(launcher.is_symlink())
        run = subprocess.run([str(launcher), "--fixture-proof"], env=env,
                             text=True, capture_output=True, timeout=10)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(run.stdout.strip(), "--fixture-proof")
        desktop = Path(env["HOME"]) / ".local/share/applications/todoist.desktop"
        self.assertIn(f'Exec="{launcher}" %U', desktop.read_text())
        self.assertNotIn("--no-sandbox", desktop.read_text())
        state = json.loads((Path(env["HOME"]) / ".local/state/dotfiles/ubuntu-packages.json").read_text())
        self.assertEqual(state["todoist"]["verification"], "https-only")
        self.assertEqual(len(state["todoist"]["download_sha256"]), 64)

    def test_td_uses_official_npm_package_with_user_local_installation(self):
        env = self.installer_environment()
        bin_dir = Path(env["HOME"]) / ".local/bin"
        bin_dir.mkdir(parents=True)
        (bin_dir / "mise").symlink_to(self.root / "bin/dispatcher")
        result = self.install_tool("td", env)
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = [json.loads(line) for line in Path(env["TEST_LOG"]).read_text().splitlines()]
        self.assertTrue(any("@doist/todoist-cli@5.8.0" in c["args"] for c in commands))
        self.assertTrue((bin_dir / "td").is_file())
        self.assertFalse(any(c["command"] == "sudo" for c in commands))

    def test_obsidian_registers_bundled_official_cli_and_requires_the_artifact(self):
        payload = b"fixture-deb"
        env = self.installer_environment(payload)
        tool = self.fixture_tool("obsidian", payload)
        tool["version"] = "fixture-version"
        env["TEST_OMIT_OBSIDIAN_CLI"] = "1"
        result = self.install_tool("obsidian", env)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("official CLI", result.stderr)
        env.pop("TEST_OMIT_OBSIDIAN_CLI")
        result = self.install_tool("obsidian", env)
        self.assertEqual(result.returncode, 0, result.stderr)
        cli = Path(env["HOME"]) / ".local/bin/obsidian"
        self.assertEqual(cli.read_bytes(), (self.root / "obsidian-cli").read_bytes())
        self.assertFalse(cli.is_symlink(), "official registration copies the bundled CLI")

    def test_zed_launcher_retains_application_bundle_and_dependencies(self):
        archive = io.BytesIO()
        with tarfile.open(fileobj=archive, mode="w:gz") as tar:
            for name, content in (("zed.app/bin/zed", b"#!/bin/sh\necho fixture-zed\n"),
                                  ("zed.app/libexec/zed-editor", b"fixture"),
                                  ("zed.app/share/icons/hicolor/512x512/apps/zed.png", b"icon")):
                entry = tarfile.TarInfo(name)
                entry.size = len(content)
                entry.mode = 0o755
                tar.addfile(entry, io.BytesIO(content))
        env = self.installer_environment(archive.getvalue())
        self.fixture_tool("zed", archive.getvalue())
        result = self.install_tool("zed", env)
        self.assertEqual(result.returncode, 0, result.stderr)
        launcher = Path(env["HOME"]) / ".local/bin/zed"
        self.assertTrue(launcher.is_symlink())
        self.assertTrue((launcher.resolve().parent.parent / "libexec/zed-editor").exists())
        desktop = Path(env["HOME"]) / ".local/share/applications/dev.zed.Zed.desktop"
        self.assertIn(f'Exec="{launcher}" %U', desktop.read_text())
        env["TEST_MISSING_LIBRARY"] = "1"
        result = self.install_tool("zed", env)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("shared libraries", result.stderr)

    def test_native_onepassword_requires_installed_signing_helper(self):
        env = self.installer_environment()
        (self.root / "container-marker").touch()
        policy = self.root / "policy-rc.d"
        policy.write_text("#!/bin/sh\nexit 101\n")
        policy.chmod(0o755)
        env["TEST_OMIT_SIGNING_HELPER"] = "1"
        result = self.install_tool("onepassword", env, "--profile", "test-container")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("signing helper", result.stderr)
        env.pop("TEST_OMIT_SIGNING_HELPER")
        result = self.install_tool("onepassword", env, "--profile", "test-container")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_workstation_decline_prevents_service_affecting_installation(self):
        env = self.installer_environment()
        (self.root / "consent").write_text("n\n")
        result = self.install_tool("onepassword", env)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("declined", result.stderr)
        commands = [json.loads(line) for line in Path(env["TEST_LOG"]).read_text().splitlines()]
        self.assertFalse(any(c["command"] in ("sudo", "apt-get", "curl") for c in commands))

    def test_brave_repository_and_rerun_do_not_duplicate_configuration(self):
        env = self.installer_environment()
        for _ in range(2):
            result = self.install_tool("brave", env)
            self.assertEqual(result.returncode, 0, result.stderr)
        sources = list((self.root / "system/etc/apt/sources.list.d").glob("*"))
        self.assertEqual(len(sources), 1)
        self.assertIn("brave-browser-apt-release.s3.brave.com", sources[0].read_text())
        self.assertEqual(sources[0].read_text().count("Signed-By:"), 1)

    def test_repository_key_fingerprint_mismatch_is_required(self):
        env = self.installer_environment()
        env["TEST_KEY_FINGERPRINT"] = "wrong-fingerprint"
        result = self.install_tool("op", env)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fingerprint mismatch", result.stderr)
        self.assertFalse((self.root / "system/etc/apt/sources.list.d").exists())

    def test_apt_binary_name_compatibility_links_are_user_local_and_rerunnable(self):
        env = self.installer_environment()
        for tool_id, binary in (("fd", "fdfind"), ("bat", "batcat")):
            with self.subTest(tool_id=tool_id):
                for _ in range(2):
                    result = self.install_tool(tool_id, env)
                    self.assertEqual(result.returncode, 0, result.stderr)
                link = Path(env["HOME"]) / ".local/bin" / tool_id
                self.assertTrue(link.is_symlink())
                self.assertEqual(link.resolve(), (self.root / "bin" / binary).resolve())

    def test_official_npm_cli_uses_mise_node_and_user_prefix_without_sudo(self):
        env = self.installer_environment()
        bin_dir = Path(env["HOME"]) / ".local/bin"
        bin_dir.mkdir(parents=True)
        (bin_dir / "mise").symlink_to(self.root / "bin/dispatcher")
        result = self.install_tool("pi", env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((bin_dir / "pi").is_file())
        commands = [json.loads(line) for line in Path(env["TEST_LOG"]).read_text().splitlines()]
        installs = [c for c in commands if "install" in c["args"]]
        self.assertTrue(any("@earendil-works/pi-coding-agent@1.4.0" in c["args"]
                            and "--ignore-scripts" in c["args"] for c in installs))
        self.assertFalse(any(c["command"] == "sudo" for c in commands))

    def test_success_records_version_owner_and_verification_provenance(self):
        payload = b"#!/bin/sh\necho fixture-herdr\n"
        env = self.installer_environment(payload)
        self.fixture_tool("herdr", payload)
        result = self.install_tool("herdr", env)
        self.assertEqual(result.returncode, 0, result.stderr)
        state = Path(env["HOME"]) / ".local/state/dotfiles/ubuntu-packages.json"
        self.assertTrue(state.exists(), "installed tool has no provenance record")
        record = json.loads(state.read_text())["herdr"]
        self.assertEqual(record["owner"], "upstream")
        self.assertEqual(record["installed_version"], "fixture-herdr")
        self.assertEqual(record["sha256"], hashlib.sha256(payload).hexdigest())
        self.assertEqual(record["provenance"], "https://herdr.dev/latest.json")

    def test_required_npm_install_failure_is_not_reported_as_success(self):
        env = self.installer_environment()
        bin_dir = Path(env["HOME"]) / ".local/bin"
        bin_dir.mkdir(parents=True)
        (bin_dir / "mise").symlink_to(self.root / "bin/dispatcher")
        env["TEST_FAIL_COMMAND"] = "mise"
        result = self.install_tool("pi", env)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("pi", result.stderr)
        self.assertFalse((Path(env["HOME"]) / ".local/state/dotfiles/ubuntu-packages.json").exists())

    def test_release_version_mismatch_is_not_recorded_as_success(self):
        payload = b"#!/bin/sh\necho wrong-version\n"
        env = self.installer_environment(payload)
        self.fixture_tool("herdr", payload)
        result = self.install_tool("herdr", env)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("herdr", result.stderr)
        self.assertIn("version differs", result.stderr)

    def test_archive_missing_declared_command_fails_with_tool_name(self):
        archive = io.BytesIO()
        with tarfile.open(fileobj=archive, mode="w:gz"):
            pass
        env = self.installer_environment(archive.getvalue())
        self.fixture_tool("starship", archive.getvalue())
        result = self.install_tool("starship", env)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("starship", result.stderr)
        self.assertIn("command is missing", result.stderr)

    def test_node_runtime_sets_user_local_npm_prefix_without_sudo(self):
        env = self.installer_environment()
        bin_dir = Path(env["HOME"]) / ".local/bin"
        bin_dir.mkdir(parents=True)
        (bin_dir / "mise").symlink_to(self.root / "bin/dispatcher")
        result = self.install_tool("node", env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((Path(env["HOME"]) / ".npmrc").read_text(), f"prefix={env['HOME']}/.local\n")
        commands = [json.loads(line) for line in Path(env["TEST_LOG"]).read_text().splitlines()]
        self.assertFalse(any(c["command"] == "sudo" for c in commands))
        runtime = next(t for t in self.catalog["tools"] if t["id"] == "node")
        self.assertIn({"command": "mise", "args": ["install", f"node@{runtime['version']}"]}, commands)

    def test_node_runtime_requires_mise_and_propagates_runtime_failures(self):
        env = self.installer_environment()
        result = self.install_tool("node", env)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("mise", result.stderr)
        bin_dir = Path(env["HOME"]) / ".local/bin"
        bin_dir.mkdir(parents=True)
        (bin_dir / "mise").symlink_to(self.root / "bin/dispatcher")
        env["TEST_FAIL_COMMAND"] = "mise"
        result = self.install_tool("node", env)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("node", result.stderr)

    def test_apt_install_failure_is_required_and_names_the_tool(self):
        env = self.installer_environment()
        env["TEST_FAIL_COMMAND"] = "apt-get"
        result = self.install_tool("ripgrep", env)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("ripgrep", result.stderr)

    def test_verified_upstream_binary_is_installed_in_target_home(self):
        payload = b"#!/bin/sh\necho fixture-herdr\n"
        env = self.installer_environment(payload)
        self.fixture_tool("herdr", payload)
        result = self.install_tool("herdr", env)
        self.assertEqual(result.returncode, 0, result.stderr)
        command = Path(env["HOME"]) / ".local/bin/herdr"
        self.assertEqual(command.read_bytes(), payload)
        self.assertEqual(subprocess.check_output([str(command)], text=True).strip(), "fixture-herdr")

    def test_upstream_download_and_integrity_failures_are_required(self):
        env = self.installer_environment()
        for failure in ("curl", "checksum"):
            with self.subTest(failure=failure):
                env["TEST_FAIL_COMMAND"] = failure
                result = self.install_tool("herdr", env)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("herdr", result.stderr)
                self.assertFalse((Path(env["HOME"]) / ".local/bin/herdr").exists())

    def test_tar_release_extracts_the_declared_command(self):
        content = b"#!/bin/sh\necho fixture-starship\n"
        archive = io.BytesIO()
        with tarfile.open(fileobj=archive, mode="w:gz") as tar:
            entry = tarfile.TarInfo("starship")
            entry.size = len(content)
            entry.mode = 0o755
            tar.addfile(entry, io.BytesIO(content))
        env = self.installer_environment(archive.getvalue())
        self.fixture_tool("starship", archive.getvalue())
        env["TEST_FAIL_COMMAND"] = "tar"
        result = self.install_tool("starship", env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((Path(env["HOME"]) / ".local/bin/starship").read_bytes(), content)

    def test_unsupported_asset_is_rejected_with_tool_name(self):
        payload = b"fixture"
        env = self.installer_environment(payload)
        self.fixture_tool("herdr", payload)["format"] = "dmg"
        result = self.install_tool("herdr", env)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("herdr", result.stderr)
        self.assertIn("unsupported", result.stderr.lower())

    def test_vendor_repository_uses_scoped_signing_key(self):
        env = self.installer_environment()
        result = self.install_tool("op", env)
        self.assertEqual(result.returncode, 0, result.stderr)
        source = self.root / "system/etc/apt/sources.list.d/1password.sources"
        self.assertIn("Signed-By: /usr/share/keyrings/1password-archive-keyring.gpg", source.read_text())
        self.assertIn("Architectures: amd64", source.read_text())
        self.assertTrue((self.root / "system/usr/share/keyrings/1password-archive-keyring.gpg").is_file())
        self.assertFalse((self.root / "system/etc/apt/trusted.gpg").exists())

    def test_macos_dispatch_keeps_existing_brewfile_invocation(self):
        env = self.installer_environment()
        env.update(TEST_OS="Darwin", BREWFILE=str(self.root / "Brewfile"))
        result = subprocess.run(
            ["zsh", str(REPO / "scripts/install-packages")],
            env=env, text=True, capture_output=True, timeout=15,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = [json.loads(line) for line in Path(env["TEST_LOG"]).read_text().splitlines()]
        self.assertIn({"command": "brew", "args": ["bundle", f"--file={env['BREWFILE']}"]}, commands)
        self.assertFalse(any(c["command"] == "apt-get" for c in commands))

    def prepare_lifecycle_fixture(self):
        source = self.root / "source"
        script = source / ".chezmoiscripts/run_onchange_after_install-packages.sh.tmpl"
        script.parent.mkdir()
        shutil.copyfile(REPO / ".chezmoiscripts/run_onchange_after_install-packages.sh.tmpl", script)
        (source / "scripts").mkdir()
        installer = source / "scripts/install-packages"
        installer.write_text('#!/usr/bin/env zsh\nprint applied >> "$HOME/invocations"\n')
        installer.chmod(0o755)
        shutil.copyfile(INSTALLER, source / "scripts/install-ubuntu-packages")
        (source / "Brewfile").write_text('brew "fixture"\n')
        (source / ".chezmoiignore").write_text('scripts/\nBrewfile\n')
        runtime = source / "dot_config/mise/config.toml.tmpl"
        runtime.parent.mkdir(parents=True)
        self.assertTrue((REPO / "dot_config/mise/config.toml.tmpl").is_file(), "mise template is missing")
        shutil.copyfile(REPO / "dot_config/mise/config.toml.tmpl", runtime)
        return source, script

    def lifecycle_command(self, source, platform):
        home = self.root / "home"
        home.mkdir(exist_ok=True)
        return [shutil.which("chezmoi"), "--config", str(self.root / "absent.toml"),
                "--source", str(source), "--destination", str(home),
                "--cache", str(self.root / "cache"), "--persistent-state", str(self.root / "state"),
                "--override-data", json.dumps({"profile": "test-container", "chezmoi": {"os": platform}})]

    def test_linux_lifecycle_watches_catalog_runtime_and_both_helpers(self):
        source, template = self.prepare_lifecycle_fixture()
        result = subprocess.run(
            [*self.lifecycle_command(source, "linux"), "execute-template"],
            input=template.read_text(), text=True, capture_output=True,
            env={"HOME": str(self.root / "home"), "PATH": os.environ["PATH"]}, timeout=15,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        for label in ("Ubuntu catalog hash:", "Ubuntu runtime hash:", "Ubuntu installer hash:", "Package dispatch hash:"):
            self.assertIn(label, result.stdout)
        self.assertNotIn("Brewfile hash:", result.stdout)

    def test_darwin_lifecycle_preserves_brewfile_trigger_and_omits_ubuntu(self):
        source, template = self.prepare_lifecycle_fixture()
        result = subprocess.run(
            [*self.lifecycle_command(source, "darwin"), "execute-template"],
            input=template.read_text(), text=True, capture_output=True,
            env={"HOME": str(self.root / "home"), "PATH": os.environ["PATH"]}, timeout=15,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        digest = hashlib.sha256((source / "Brewfile").read_bytes()).hexdigest()
        self.assertIn(f"Brewfile hash: {digest}", result.stdout)
        self.assertNotIn("UBUNTU_CATALOG", result.stdout)
        self.assertNotIn("mise", result.stdout)

    def test_manifest_changes_rerun_installer_but_unchanged_apply_does_not(self):
        source, _ = self.prepare_lifecycle_fixture()
        command = [*self.lifecycle_command(source, "linux"), "apply"]
        env = {"HOME": str(self.root / "home"), "PATH": os.environ["PATH"]}
        invocations = self.root / "home/invocations"
        for path, count in ((None, 1), (None, 1),
                            (source / ".chezmoidata/ubuntu.yaml", 2),
                            (source / "dot_config/mise/config.toml.tmpl", 3),
                            (source / "scripts/install-ubuntu-packages", 4),
                            (source / "scripts/install-packages", 5)):
            with self.subTest(path=path, count=count):
                if path is not None:
                    with path.open("a") as file:
                        file.write("\n# changed fixture content\n")
                result = subprocess.run(command, env=env, text=True, capture_output=True, timeout=15)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(invocations.read_text().count("applied\n"), count)
        runtime = (self.root / "home/.config/mise/config.toml").read_text()
        self.assertEqual(runtime.count("[tools]"), 1)
        self.assertEqual(runtime.count('node = "'), 1)

    def test_setup_checklist_covers_catalog_and_separates_pending_machine_checks(self):
        path = REPO / "docs/ubuntu.md"
        self.assertTrue(path.exists(), "Ubuntu setup checklist is missing")
        document = path.read_text()
        for tool in self.catalog["tools"]:
            for command in tool["commands"]:
                self.assertIn(f"`{command}`", document)
        for topic in ("Touch ID", "passwordless sudo", "sign-in", "Pending", "Docker Engine"):
            self.assertIn(topic, document)

    def test_catalog_covers_every_selected_command_and_has_valid_owners(self):
        result = self.validate(self.catalog)
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = {c for tool in self.catalog["tools"] for c in tool["commands"]}
        self.assertEqual(commands, REQUIRED_COMMANDS)

    def test_missing_owner_is_rejected(self):
        del self.catalog["tools"][0]["owner"]
        self.assertNotEqual(self.validate(self.catalog).returncode, 0)

    def test_duplicate_command_is_rejected(self):
        self.catalog["tools"][1]["commands"].append(self.catalog["tools"][0]["commands"][0])
        self.assertNotEqual(self.validate(self.catalog).returncode, 0)

    def test_duplicate_tool_is_rejected(self):
        self.catalog["tools"].append(copy.deepcopy(self.catalog["tools"][0]))
        self.assertNotEqual(self.validate(self.catalog).returncode, 0)

    def test_general_cli_cannot_be_owned_by_mise(self):
        tool = next(t for t in self.catalog["tools"] if t["id"] == "starship")
        tool["owner"] = "mise"
        self.assertNotEqual(self.validate(self.catalog).returncode, 0)

    def test_upstream_without_integrity_or_version_is_rejected(self):
        for field in ("version", "sha256"):
            with self.subTest(field=field):
                catalog = copy.deepcopy(self.catalog)
                tool = next(t for t in catalog["tools"] if t["id"] == "herdr")
                del tool[field]
                self.assertNotEqual(self.validate(catalog).returncode, 0)

    def test_unsupported_catalog_architecture_is_rejected(self):
        self.catalog["architecture"] = "arm64"
        self.assertNotEqual(self.validate(self.catalog).returncode, 0)


if __name__ == "__main__":
    unittest.main()
