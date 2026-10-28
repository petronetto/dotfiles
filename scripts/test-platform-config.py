#!/usr/bin/env python3
"""Platform contracts using temporary homes, rendered files, and fake CLI boundaries."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
BOUNDARY = r'''
import json
import os
from pathlib import Path
import sys
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["TEST_LOG"], "a") as log:
    log.write(json.dumps({"command": name, "args": args}) + "\n")
if name == "uname":
    print("arm64" if os.environ["TEST_PLATFORM"] == "darwin" else "x86_64")
elif name == "brew":
    print("export BREW_FIXTURE_ACTIVE=1")
elif name == "locale":
    print("C\nC.utf8\nen_US.utf8")
elif name == "mise":
    print('export PATH="' + os.environ["TEST_BIN"] + '/shims:$PATH"')
elif name == "starship":
    print('PROMPT="fixture> "')
elif name == "zoxide":
    print('z() { builtin cd "$@"; }')
elif name == "atuin":
    print(":")
elif name in ("pbcopy", "wl-copy", "xclip"):
    content = sys.stdin.read()
    if os.environ.get("TEST_CLIPBOARD_FAIL"):
        sys.exit(42)
    Path(os.environ["TEST_CLIPBOARD"]).write_text(content)
elif name == "node":
    print("42")
else:
    print("blocked external command: " + name, file=sys.stderr)
    sys.exit(99)
'''


class PlatformTests(unittest.TestCase):
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
        dispatcher.write_text(f"#!{sys.executable}\n" + BOUNDARY)
        dispatcher.chmod(0o755)
        for command in ("uname", "brew", "locale", "starship", "zoxide", "atuin",
                        "pbcopy", "wl-copy", "xclip", "git", "sudo", "open", "osascript"):
            (self.bin / command).symlink_to(dispatcher)
        (self.bin / "shims").mkdir()
        (self.bin / "shims/node").symlink_to(dispatcher)
        local_bin = self.home / ".local/bin"
        local_bin.mkdir(parents=True)
        (local_bin / "mise").symlink_to(dispatcher)
        self.source = self.root / "source"
        self.source.mkdir()
        public_key = self.source / "private_dot_ssh/private_petronetto.pub"
        public_key.parent.mkdir()
        public_key.write_text("ssh-ed25519 fixture-public-key\n")
        self.env = {
            "HOME": str(self.home), "PATH": f"{self.bin}:/usr/bin:/bin:/usr/sbin:/sbin",
            "TEST_BIN": str(self.bin), "TEST_LOG": str(self.log),
            "TEST_PLATFORM": "linux", "TERM": "xterm-kitty", "LANG": "C.UTF-8",
            "TEST_CLIPBOARD": str(self.root / "clipboard"),
            "LC_ALL": "C", "HISTFILE": str(self.home / ".zsh_history"),
        }

    def source_file(self, relative):
        template = REPO / (relative + ".tmpl")
        return template if template.exists() else REPO / relative

    def render(self, relative, platform):
        path = self.source_file(relative)
        self.assertTrue(path.exists(), path)
        result = subprocess.run(
            [shutil.which("chezmoi"), "--config", str(self.root / "absent.toml"),
             "--source", str(self.source), "--destination", str(self.home),
             "execute-template", "--override-data", json.dumps({
                 "git_email": "fixture@example.invalid", "profile": "test-container",
                 "chezmoi": {"os": platform, "arch": "amd64", "homeDir": str(self.home)},
             })], input=path.read_text(), text=True, capture_output=True, timeout=15,
            env={"HOME": str(self.home), "PATH": os.environ["PATH"]},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def prepare_shell(self, platform="linux"):
        zsh_dir = Path(self.env.get("XDG_CONFIG_HOME", self.home / ".config")) / "zsh"
        zsh_dir.mkdir(parents=True, exist_ok=True)
        for path in (REPO / "dot_config/zsh").rglob("*"):
            if not path.is_file():
                continue
            relative = path.relative_to(REPO / "dot_config/zsh")
            destination = zsh_dir / relative
            if destination.name.startswith("dot_"):
                destination = destination.with_name("." + destination.name[4:])
            destination.parent.mkdir(parents=True, exist_ok=True)
            content = path.read_text()
            content = content.replace("/opt/homebrew/bin/brew", str(self.bin / "brew"))
            content = content.replace("/usr/local/bin/brew", str(self.bin / "brew"))
            destination.write_text(content)
        os_type = "darwin26.0" if platform == "darwin" else "linux-gnu"
        (self.home / ".zshenv").write_text(f'OSTYPE={os_type}\nsource "{zsh_dir}/.zshenv"\n')
        (zsh_dir / ".antidote").mkdir(exist_ok=True)
        plugins = zsh_dir / ".zsh_plugins.zsh"
        plugins.write_text("export FIXTURE_PLUGIN_LOADED=1\n")
        timestamp = (zsh_dir / "zsh_plugins.txt").stat().st_mtime + 5
        os.utime(plugins, (timestamp, timestamp))
        (Path(self.env.get("XDG_DATA_HOME", self.home / ".local/share")) / "tmux/plugins/tpm").mkdir(parents=True, exist_ok=True)
        (Path(self.env.get("XDG_CACHE_HOME", self.home / ".cache")) / "zsh").mkdir(parents=True, exist_ok=True)
        self.env["TEST_PLATFORM"] = platform

    def shell(self, command, *, login=True):
        flags = "-dlic" if login else "-dic"
        return subprocess.run(["/bin/zsh", flags, command], env=self.env,
                              cwd=self.home, text=True, capture_output=True, timeout=15)

    def commands(self):
        if not self.log.exists():
            return []
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_linux_preserves_terminal_runtime_and_search_paths(self):
        self.prepare_shell()
        runtime = self.root / "runtime"
        runtime.mkdir(mode=0o700)
        self.env.update(XDG_RUNTIME_DIR=str(runtime), XDG_CONFIG_DIRS="/fixture/config",
                        XDG_DATA_DIRS="/fixture/share:/usr/share")
        result = self.shell('print -r -- "STATE:$TERM|$XDG_RUNTIME_DIR|$XDG_CONFIG_DIRS|$XDG_DATA_DIRS"')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"STATE:xterm-kitty|{runtime}|/fixture/config|/fixture/share:/usr/share", result.stdout)

    def test_headless_linux_does_not_invent_a_runtime_directory(self):
        self.prepare_shell()
        result = self.shell('print -r -- "RUNTIME:${XDG_RUNTIME_DIR-UNSET}"')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("RUNTIME:UNSET", result.stdout)

    def test_linux_uses_available_locale_and_does_not_load_homebrew(self):
        self.prepare_shell()
        result = self.shell('print -r -- "LANG:$LANG"')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("LANG:C.UTF-8", result.stdout)
        self.assertFalse(any(c["command"] == "brew" for c in self.commands()))

    def test_linux_replaces_unavailable_locale_with_an_installed_locale(self):
        self.env["LANG"] = "unavailable.UTF-8"
        self.prepare_shell()
        result = self.shell('print -r -- "LANG:$LANG"')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("LANG:en_US.UTF-8", result.stdout)

    def test_linux_preserves_session_xdg_home_directories(self):
        self.env.update(XDG_CONFIG_HOME=str(self.root / "config"),
                        XDG_DATA_HOME=str(self.root / "data"), XDG_CACHE_HOME=str(self.root / "cache"))
        self.prepare_shell()
        result = self.shell('print -r -- "STATE:$XDG_CONFIG_HOME|$XDG_DATA_HOME|$XDG_CACHE_HOME"')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"STATE:{self.root}/config|{self.root}/data|{self.root}/cache", result.stdout)

    def test_repeated_linux_initialization_keeps_unique_paths_and_primed_plugins(self):
        self.prepare_shell()
        result = self.shell('source "$ZDOTDIR/.zshrc"; print -r -- "PLUGIN:$FIXTURE_PLUGIN_LOADED"; print -rl -- $path')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PLUGIN:1", result.stdout)
        self.assertEqual(result.stdout.splitlines().count(str(self.home / ".local/bin")), 1)
        self.assertFalse(any(c["command"] == "git" for c in self.commands()))

    def test_linux_core_alias_targets_exist(self):
        self.prepare_shell()
        result = self.shell('print -r -- "ALIAS:${aliases[vim]}|${aliases[cat]}|${aliases[dc]}|${aliases[..]}"')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ALIAS:nvim|bat|docker compose|cd ..", result.stdout)
        self.assertFalse(any(c["command"] == "git" for c in self.commands()))

    def test_wayland_and_x11_clipboard_copy_keep_navigation_text(self):
        for session in ("wayland", "x11"):
            with self.subTest(session=session):
                self.prepare_shell()
                self.env.pop("WAYLAND_DISPLAY", None)
                self.env.pop("DISPLAY", None)
                if session == "wayland":
                    self.env.update(WAYLAND_DISPLAY="wayland-0", XDG_RUNTIME_DIR=str(self.root))
                else:
                    self.env["DISPLAY"] = ":fixture"
                result = self.shell("pwd; wait")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(str(self.home), result.stdout)
                self.assertEqual(Path((self.root / "clipboard").read_text().strip()), self.home.resolve())
                expected = "wl-copy" if session == "wayland" else "xclip"
                self.assertTrue(any(c["command"] == expected for c in self.commands()))

    def test_unavailable_clipboard_service_does_not_fail_navigation(self):
        self.prepare_shell()
        self.env.update(DISPLAY=":unavailable", TEST_CLIPBOARD_FAIL="1")
        result = self.shell("pwd; wait")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(str(self.home), result.stdout)
        self.assertEqual(result.stderr, "")

    def test_nonlogin_interactive_linux_activates_runtime_before_cli_use(self):
        self.prepare_shell()
        result = self.shell('node -p "6 * 7"', login=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "42")

    def test_cold_completion_cache_is_created_without_startup_errors(self):
        self.prepare_shell()
        (self.home / ".cache/zsh").rmdir()
        result = self.shell('print -r -- "PLUGIN:$FIXTURE_PLUGIN_LOADED"')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        self.assertTrue((self.home / ".cache/zsh/.zcompdump").exists())

    def test_headless_navigation_retains_text_without_macos_clipboard(self):
        self.prepare_shell()
        result = self.shell("pwd; wait")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(str(self.home), result.stdout)
        self.assertFalse(any(c["command"] == "pbcopy" for c in self.commands()))
        self.assertEqual(result.stderr, "")

    def test_linux_has_no_macos_docker_start_or_display_helper(self):
        self.prepare_shell()
        result = self.shell('print -r -- "ZOOM:${+functions[zoom]}"; alias docker-init')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ZOOM:0", result.stdout)
        self.assertNotIn("open --background", result.stdout)

    def test_darwin_shell_keeps_existing_integrations(self):
        self.prepare_shell("darwin")
        result = self.shell('print -r -- "STATE:$TERM|$LANG|$SSH_AUTH_SOCK|${+functions[zoom]}"; alias docker-init')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("STATE:xterm-256color|en_GB.UTF-8|", result.stdout)
        self.assertIn("Library/Group Containers/", result.stdout)
        self.assertIn("|1", result.stdout)
        self.assertIn("open --background -a Docker", result.stdout)
        self.assertTrue(any(c["command"] == "brew" for c in self.commands()))
        self.assertFalse(any(c["command"] == "mise" for c in self.commands()))

    def test_linux_git_and_ssh_use_native_onepassword_paths(self):
        git = self.render("dot_config/git/config", "linux")
        ssh = self.render("private_dot_ssh/config", "linux")
        self.assertIn("/opt/1Password/op-ssh-sign", git)
        self.assertIn(".1password/agent.sock", ssh)
        self.assertNotIn("/Applications", git)
        self.assertNotIn("Library/Group Containers", ssh)

    def test_darwin_git_and_ssh_keep_existing_onepassword_paths(self):
        git = self.render("dot_config/git/config", "darwin")
        ssh = self.render("private_dot_ssh/config", "darwin")
        self.assertIn("/Applications/1Password.app/Contents/MacOS/op-ssh-sign", git)
        self.assertIn("Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock", ssh)

    def test_linux_ghostty_omits_macos_options_and_keeps_appearance(self):
        config = self.render("dot_config/ghostty/config", "linux")
        self.assertIn("theme = Gruvbox Custom", config)
        self.assertNotIn("macos-", config)
        self.assertNotIn("global:cmd", config)
        self.assertIn("ctrl+shift+space", config)

    def test_darwin_ghostty_preserves_existing_platform_values(self):
        config = self.render("dot_config/ghostty/config", "darwin")
        for value in ("font-family = JetBrainsMono NFM Light", "macos-titlebar-style = hidden",
                      "macos-option-as-alt = left", "global:cmd+shift+space=toggle_quick_terminal"):
            self.assertIn(value, config)


if __name__ == "__main__":
    unittest.main()
