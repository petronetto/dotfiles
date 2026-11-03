#!/usr/bin/env python3
"""Test credential-safe PTY provisioning without host privilege changes."""

import importlib.util
import io
import os
import sys
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
DRIVER = REPO / "tests/ubuntu/provision.py"


class ProvisionPtyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("ubuntu_provision", DRIVER)
        cls.provision = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = cls.provision
        spec.loader.exec_module(cls.provision)

    def run_command(self, program, timeout=3):
        output = io.StringIO()
        request = self.provision.PtyCommand([sys.executable, "-c", program], dict(os.environ))
        code = self.provision.run_pty(request, "synthetic-fixture-password", output, timeout=timeout)
        return code, output.getvalue()

    def test_sudo_prompt_receives_fixture_credential_without_echoing_it(self):
        program = '''
import sys
print("[sudo] password for tester:", end="", flush=True)
value = sys.stdin.readline().strip()
print("credential received" if value == "synthetic-fixture-password" else "wrong input")
sys.exit(0 if value == "synthetic-fixture-password" else 9)
'''

        code, output = self.run_command(program)

        self.assertEqual(code, 0)
        self.assertIn("credential received", output)
        self.assertNotIn("synthetic-fixture-password", output)

    def test_child_failure_is_propagated_without_being_reported_as_success(self):
        code, output = self.run_command('print("controlled bootstrap failure"); raise SystemExit(19)')

        self.assertEqual(code, 19)
        self.assertIn("controlled bootstrap failure", output)

    def test_hung_bootstrap_is_bounded(self):
        code, output = self.run_command("import time; time.sleep(30)", timeout=0.1)

        self.assertEqual(code, 124)
        self.assertIn("timed out", output)

    def test_credential_is_redacted_even_if_a_child_prints_it_in_chunks(self):
        program = '''
import sys, time
sys.stdout.write("synthetic-fixture-")
sys.stdout.flush()
time.sleep(0.05)
sys.stdout.write("password")
sys.stdout.flush()
'''

        code, output = self.run_command(program)

        self.assertEqual(code, 0)
        self.assertNotIn("synthetic-fixture-password", output)
        self.assertIn("[redacted]", output)


if __name__ == "__main__":
    unittest.main()
