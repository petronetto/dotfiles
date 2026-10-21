#!/usr/bin/env python3
"""Run isolated storage-contract tests with a fake external vault CLI."""

import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
CLI = REPO / "dot_agents/plan-adapters/executable_plan"


class AdapterTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.vault = self.root / "vault"
        self.vault.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        fake = self.bin / "obsidian"
        fake.write_text('''#!/usr/bin/env python3
import os
from pathlib import Path
import sys
root = Path(os.environ["TEST_VAULT"])
args = sys.argv[2:]
values = dict(arg.split("=", 1) for arg in args if "=" in arg)
op = args[0]
if os.environ.get("TEST_VAULT_ERROR"):
    print("Error: vault unavailable")
elif op == "vault":
    print(root)
elif op == "folders":
    folder = root / values["folder"]
    if folder.exists():
        print(folder.relative_to(root))
        for path in folder.rglob("*"):
            if path.is_dir():
                print(path.relative_to(root))
elif op == "folder":
    if not (root / values["path"]).is_dir():
        print("Error: Folder not found.")
elif op == "create":
    path = root / values["path"]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(values["content"])
elif op == "delete":
    (root / values["path"]).unlink()
else:
    raise SystemExit("unexpected operation")
''')
        fake.chmod(0o755)
        self.config = self.root / "plans.config.md"
        self.config.write_text(
            f"---\ndisk:\n  root: {self.root}/configured plans\n"
            "obsidian:\n  vault: Test\n  folder: Custom Plans/<repo-name>\n---\n"
        )
        self.cwd = REPO
        self.env = {
            **os.environ,
            "PLAN_CONFIG": str(self.config),
            "TEST_VAULT": str(self.vault),
            "PATH": f"{self.bin}:{os.environ['PATH']}",
        }
        for key in ("PLAN_BACKENDS_DIR", "PLAN_REPO_ROOT", "TEST_VAULT_ERROR"):
            self.env.pop(key, None)

    def run_cli(self, backend, *args, content=None, success=True):
        result = subprocess.run(
            ["bash", str(CLI), *args], input=content, text=True,
            capture_output=True, cwd=self.cwd,
            env={**self.env, "PLAN_BACKEND": backend},
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result

    def test_nested_specs_round_trip_and_files_are_task_relative(self):
        for backend in ("disk", "obsidian"):
            with self.subTest(backend=backend):
                location = self.run_cli(backend, "init", "add-auth").stdout.strip()
                name = "specs/identity/user-auth/spec.md"
                content = "# Spec Delta\n\n## ADDED Requirements\nLiteral: \\n \\t\n"
                self.run_cli(backend, "write", location, name, content=content)
                result = self.run_cli(backend, "read", location, name)
                self.assertEqual(result.stdout, content)
                self.run_cli(backend, "append", location, name, content="More\n")
                self.assertEqual(
                    self.run_cli(backend, "read", location, name).stdout,
                    content + "\nMore\n",
                )
                self.assertEqual(
                    self.run_cli(backend, "files", location).stdout.splitlines(), [name]
                )
                self.assertIn(location, self.run_cli(backend, "list").stdout.splitlines())

    def test_empty_discovery_does_not_create_storage(self):
        for backend in ("disk", "obsidian"):
            with self.subTest(backend=backend):
                self.assertEqual(self.run_cli(backend, "list").stdout, "")
        self.assertFalse((self.root / "configured plans").exists())
        self.assertEqual(list(self.vault.iterdir()), [])

    def test_rejects_invalid_nested_names_without_writing_outside_task(self):
        for backend in ("disk", "obsidian"):
            location = self.run_cli(backend, "init", "safe-task").stdout.strip()
            for name in ("../escape.md", "specs/../../escape.md", "/escape.md",
                         "specs//spec.md", "specs/./spec.md", "specs/../spec.md"):
                with self.subTest(backend=backend, name=name):
                    self.run_cli(backend, "write", location, name, content="bad", success=False)
            self.assertEqual(self.run_cli(backend, "files", location).stdout, "")

    def test_rejects_symlink_files_and_ancestors(self):
        for backend in ("disk", "obsidian"):
            location = self.run_cli(backend, "init", "safe-task").stdout.strip()
            directory = Path(self.run_cli(backend, "path", location).stdout.strip())
            outside = self.root / f"outside-{backend}"
            outside.mkdir()
            target = outside / "spec.md"
            target.write_text("unchanged")
            (directory / "linked").symlink_to(outside, target_is_directory=True)
            (directory / "linked.md").symlink_to(target)
            for op in ("read", "write", "append"):
                for name in ("linked/spec.md", "linked.md"):
                    with self.subTest(backend=backend, op=op, name=name):
                        self.run_cli(backend, op, location, name, content="bad", success=False)
            self.assertEqual(target.read_text(), "unchanged")
            self.run_cli(backend, "files", location, success=False)

    def test_flat_files_and_step_status_remain_compatible(self):
        step = "| Status | pending |\n| Depends | none |\n\n## Acceptance\n- [ ] Check\n"
        for backend in ("disk", "obsidian"):
            with self.subTest(backend=backend):
                location = self.run_cli(backend, "init", "old-task").stdout.strip()
                self.run_cli(backend, "write", location, "000-step.md", content=step)
                self.run_cli(backend, "set-status", location, "--step", "000-step.md",
                             "--status", "blocked", "--reason", "Needs input")
                self.run_cli(backend, "set-status", location, "--step", "000-step.md",
                             "--status", "done")
                self.assertEqual(
                    self.run_cli(backend, "read", location, "000-step.md").stdout,
                    step.replace("pending", "done"),
                )

    def test_change_artifacts_and_main_specs_remain_separate(self):
        for backend in ("disk", "obsidian"):
            with self.subTest(backend=backend):
                catalog = self.run_cli(backend, "init", "specs").stdout.strip()
                location = self.run_cli(backend, "init", "add-search").stdout.strip()
                baseline = "# Search\n\n## Purpose\nExisting search behavior.\n"
                self.run_cli(backend, "write", catalog, "search/spec.md", content=baseline)
                artifacts = {
                    ".change.yaml": "schema: spec-driven\nskip_specs: false\n",
                    "proposal.md": "# Proposal\n\n## Why\nSearch needs filters.\n",
                    "specs/search/spec.md": "## MODIFIED Requirements\n\n### Requirement: Filter search\nThe system SHALL filter results.\n\n#### Scenario: Matching results\n- **WHEN** a filter is provided\n- **THEN** matching results are returned\n",
                    "design.md": "# Design\n\n## Decisions\nUse the existing index.\n",
                    "tasks.md": "# Tasks\n\n## 1. Search\n\n- [ ] 1.1 Add filters and run search tests\n",
                }
                for name, content in artifacts.items():
                    self.run_cli(backend, "write", location, name, content=content)
                completed = artifacts["tasks.md"].replace("- [ ]", "- [x]")
                self.run_cli(backend, "write", location, "tasks.md", content=completed)
                self.assertEqual(self.run_cli(backend, "read", location, "tasks.md").stdout, completed)
                self.assertEqual(self.run_cli(backend, "files", location).stdout.splitlines(), sorted(artifacts))
                self.assertEqual(self.run_cli(backend, "read", catalog, "search/spec.md").stdout, baseline)

    def test_relative_root_is_anchored_to_git_project(self):
        self.cwd = self.root / "example-project"
        self.cwd.mkdir()
        subprocess.run(["git", "init", "-q", str(self.cwd)], check=True)
        self.config.write_text("---\ndisk:\n  root: Custom Plans/<repo-name>\n---\n")
        location = self.run_cli("disk", "init", "add-auth").stdout.strip()
        self.assertEqual(Path(location).resolve(), (self.cwd / "Custom Plans/example-project/add-auth").resolve())

    def test_vault_discovery_errors_are_not_empty_inventories(self):
        self.env["TEST_VAULT_ERROR"] = "1"
        result = self.run_cli("obsidian", "list", success=False)
        self.assertIn("vault unavailable", result.stderr)

    def test_backend_and_config_errors_do_not_fall_back(self):
        self.config.write_text("---\ndisk:\n  wrong: root\n---\n")
        self.run_cli("disk", "list", success=False)
        self.run_cli("unknown", "list", success=False)
        self.assertFalse((self.root / "configured plans").exists())


class SkillContractTests(unittest.TestCase):
    skills = ("apply-change", "continue-change", "explore", "propose", "verify-change")
    adapters = REPO / "dot_agents/plan-adapters"

    def test_skill_names_and_metadata_are_discoverable_without_legacy_cli(self):
        for name in self.skills:
            with self.subTest(skill=name):
                path = REPO / "dot_agents/skills" / name / "SKILL.md"
                _, metadata, body = path.read_text().split("---", 2)
                self.assertIn(f"name: {name}\n", metadata)
                self.assertIn("license: MIT\n", metadata)
                author = re.search(r"  author: (.+)", metadata).group(1)
                self.assertNotIn(author.lower(), body.lower())
                self.assertNotIn("opsx", body.lower())
                self.assertIn("../../plan-adapters/change-workflow.md", body)
                self.assertIn("~/.agents/plans.config.md", body)
                self.assertNotRegex(body, r"CONTEXT\.md|DECISIONS\.md|PRD\.md|SPEC\.md|set-status")

    def test_all_schema_templates_are_bundled(self):
        schema = self.adapters / "schemas/spec-driven/schema.yaml"
        content = schema.read_text()
        names = re.findall(r"    template: (.+)", content)
        self.assertEqual(names, ["proposal.md", "spec.md", "design.md", "tasks.md"])
        for name in names:
            self.assertTrue((schema.parent / "templates" / name).is_file(), name)
        self.assertIn('generates: "specs/**/*.md"', content)
        for operation in ("ADDED", "MODIFIED", "REMOVED", "RENAMED"):
            self.assertIn(f"{operation} Requirements", content)
        self.assertIn("requires: [tasks]", content)
        self.assertIn("tracks: tasks.md", content)

    def test_workflows_keep_their_distinct_boundaries(self):
        texts = {name: (REPO / "dot_agents/skills" / name / "SKILL.md").read_text()
                 for name in self.skills}
        self.assertIn("loop until done or blocked", texts["apply-change"])
        self.assertIn("STOP after creating ONE artifact", texts["continue-change"])
        self.assertIn("generate all artifacts in one step", texts["propose"])
        self.assertIn("thinking, not implementing", texts["explore"])
        self.assertIn("Do not implement tasks", texts["verify-change"])
        for operation in ("REMOVED", "RENAMED"):
            self.assertIn(operation, texts["verify-change"])
        self.assertIn("Not verified", texts["verify-change"])
        self.assertIn("Not applicable", texts["verify-change"])


if __name__ == "__main__":
    unittest.main()
