#!/usr/bin/env python3
"""Smoke-gate contracts; tool and operating-system seams use synthetic fixtures."""

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
RUNNER = REPO / "scripts/ubuntu-smoke.py"


class SmokeGateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("ubuntu_smoke", RUNNER)
        cls.smoke = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = cls.smoke
        spec.loader.exec_module(cls.smoke)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.script = self.root / "check.zsh"
        self.script.write_text('print -r -- "credential-free behavior: $1"\n')
        self.catalog = {"tools": [{"id": "shell", "commands": ["zsh"]}]}
        self.registry = {"schema": 1, "checks": [{"command": "zsh", "script": "check.zsh", "timeout": 5}]}
        self.manifest = {"source_digest": "a" * 64, "image": "sha256:" + "b" * 64, "platform": "linux/amd64"}
        self.versions = {"shell": {"installed_version": "zsh fixture version"}}
        self.runtime = {"os": "Linux", "architecture": "x86_64", "uid": 1000}

    def report(self, only=None):
        return self.smoke.evaluate(
            self.catalog, self.registry, self.root, self.manifest, self.versions,
            self.runtime, only=only,
        )

    def test_success_identifies_source_image_architecture_versions_and_executed_behavior(self):
        report = self.report()

        self.assertEqual(report["status"], "passed")
        self.assertEqual(report["source"], self.manifest)
        self.assertEqual(report["runtime"], self.runtime)
        self.assertEqual(report["versions"]["shell"], "zsh fixture version")
        self.assertEqual(report["results"][0]["exit_code"], 0)
        self.assertIn("credential-free behavior: zsh", report["results"][0]["output"])
        self.assertTrue(report["pending_machine_checks"])

    def test_catalog_command_without_a_registered_check_blocks_acceptance(self):
        self.registry["checks"] = []

        report = self.report()

        self.assertEqual(report["status"], "failed")
        self.assertEqual(report["results"][0]["status"], "missing")

    def test_registered_check_without_a_script_blocks_acceptance(self):
        self.script.unlink()

        report = self.report()

        self.assertEqual(report["status"], "failed")
        self.assertEqual(report["results"][0]["status"], "missing")

    def test_missing_installed_command_blocks_acceptance(self):
        self.catalog["tools"][0]["commands"] = ["fixture-not-installed-dotfiles"]
        self.registry["checks"][0]["command"] = "fixture-not-installed-dotfiles"

        report = self.report()

        self.assertEqual(report["status"], "failed")
        self.assertEqual(report["results"][0]["status"], "missing")

    def test_skip_failure_and_timeout_are_never_passing_checks(self):
        for code, expected in ((77, "skipped"), (9, "failed")):
            with self.subTest(code=code):
                self.script.write_text(f"exit {code}\n")

                report = self.report()

                self.assertEqual(report["status"], "failed")
                self.assertEqual(report["results"][0]["status"], expected)
                self.assertEqual(report["results"][0]["exit_code"], code)

    def test_timeout_is_bounded_and_reports_failure(self):
        self.script.write_text("sleep 30\n")
        self.registry["checks"][0]["timeout"] = 0.1

        report = self.report()

        self.assertEqual(report["status"], "failed")
        self.assertEqual(report["results"][0]["exit_code"], 124)
        self.assertIn("timed out", report["results"][0]["output"])

    def test_focused_run_records_unexecuted_commands_and_cannot_pass_full_gate(self):
        self.catalog["tools"].append({"id": "git", "commands": ["git"]})
        self.registry["checks"].append({"command": "git", "script": "check.zsh", "timeout": 5})
        self.versions["git"] = {"installed_version": "fixture git"}

        report = self.report(only="zsh")

        self.assertEqual(report["status"], "failed")
        self.assertEqual(report["results"][0]["status"], "passed")
        self.assertEqual(report["results"][1]["status"], "unexecuted")

    def test_output_is_bounded_without_changing_successful_exit_status(self):
        self.script.write_text("printf '%20000s' bounded\n")

        report = self.report()

        self.assertEqual(report["status"], "passed")
        self.assertLessEqual(len(report["results"][0]["output"]), self.smoke.MAX_OUTPUT_BYTES)
        self.assertTrue(report["results"][0]["output_truncated"])

    def test_missing_evidence_wrong_architecture_or_root_execution_blocks_acceptance(self):
        for field, value in (("uid", 0), ("architecture", "aarch64"), ("os", "Darwin")):
            with self.subTest(field=field):
                self.runtime = {"os": "Linux", "architecture": "x86_64", "uid": 1000, field: value}

                report = self.report()

                self.assertEqual(report["status"], "failed")
                self.assertTrue(report["errors"])
                self.assertEqual(report["results"][0]["status"], "unexecuted")
        self.runtime = {"os": "Linux", "architecture": "x86_64", "uid": 1000}
        self.versions = {}

        report = self.report()

        self.assertEqual(report["status"], "failed")
        self.assertIn("version", " ".join(report["errors"]))

    def test_invalid_source_evidence_never_executes_checks(self):
        self.manifest["source_digest"] = ""

        report = self.report()

        self.assertEqual(report["status"], "failed")
        self.assertEqual(report["results"][0]["status"], "unexecuted")

    def test_shipped_registry_covers_exactly_the_catalog_commands(self):
        result = subprocess.run(
            ["chezmoi", "--config", str(self.root / "absent.toml"), "--source", str(REPO),
             "execute-template", "{{ .ubuntu | toJson }}"],
            capture_output=True, text=True, timeout=10, check=True,
        )
        required = [command for tool in json.loads(result.stdout)["tools"] for command in tool["commands"]]
        registry = json.loads((REPO / "tests/ubuntu/smoke/registry.json").read_text())

        registered = [check["command"] for check in registry["checks"]]

        self.assertCountEqual(registered, required)
        self.assertEqual(len(set(registered)), len(registered))

    def test_duplicate_or_stale_registry_commands_are_rejected(self):
        self.registry["checks"].append(dict(self.registry["checks"][0]))

        with self.assertRaisesRegex(ValueError, "duplicate"):
            self.report()

        self.registry["checks"][-1]["command"] = "stale-command"
        with self.assertRaisesRegex(ValueError, "catalog"):
            self.report()

    def test_script_cannot_escape_registry_directory(self):
        self.registry["checks"][0]["script"] = "../outside.zsh"

        with self.assertRaisesRegex(ValueError, "directory"):
            self.report()

    def test_atomic_failed_report_replaces_a_previous_success(self):
        destination = self.root / "report.json"
        destination.write_text('{"status":"passed"}')

        self.smoke.save_report(destination, {"status": "failed", "results": []})

        self.assertEqual(json.loads(destination.read_text())["status"], "failed")
        self.assertEqual(destination.stat().st_mode & 0o777, 0o600)


if __name__ == "__main__":
    unittest.main()
