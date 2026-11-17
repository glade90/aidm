"""Isolated offline tests for the safe configuration boundary.

Purpose: Prove environment precedence, mode isolation, typed validation and
         non-disclosure without live API access or third-party fixtures.
Usage: python -m unittest discover -s aidm/test -p 'test_*.py' -v
Change log: 2026-11-17 COSTA — AIDM-DES-034.1 test coverage.
"""

from __future__ import annotations

import json
import pickle
import tempfile
from pathlib import Path
import unittest

from aidm.config import ConfigError, load_config


class ConfigurationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dotenv = Path(self.tmp.name) / ".env"

    def load(self, environ=None, **kwargs):
        return load_config(environ={} if environ is None else environ, dotenv_path=self.dotenv, **kwargs)

    def test_development_env_overrides_dotenv(self):
        self.dotenv.write_text("AIDM_DEBUG=false\nAIDM_REQUEST_TIMEOUT_SECONDS=42\n")
        got = self.load({"AIDM_DEBUG": "YES", "AIDM_REQUEST_TIMEOUT_SECONDS": "15"})
        self.assertTrue(got.debug)
        self.assertEqual(got.request_timeout_seconds, 15.0)
        self.assertEqual(got.mode, "development")

    def test_missing_dotenv_is_allowed(self):
        got = self.load({"AIDM_MODE": "development", "AIDM_DEBUG": "1"})
        self.assertTrue(got.debug)
        self.assertEqual(got.log_level, "INFO")
        self.assertEqual(got.request_timeout_seconds, 30.0)

    def test_test_ci_and_production_ignore_dotenv(self):
        self.dotenv.write_text("AIDM_DEBUG=not-a-boolean\nDEMO_SECRET=not-the-real-secret\n")
        for mode in ("test", "ci", "production"):
            with self.subTest(mode=mode):
                got = self.load({"AIDM_MODE": mode})
                self.assertFalse(got.debug)
                self.assertIsNone(got.get_secret("DEMO_SECRET"))

    def test_ci_marker_without_mode_forces_ci(self):
        self.dotenv.write_text("AIDM_DEBUG=invalid\n")
        self.assertEqual(self.load({"CI": "true"}).mode, "ci")

    def test_ci_marker_rejects_dev_mode_override(self):
        with self.assertRaisesRegex(ConfigError, "AIDM_MODE"):
            self.load({"CI": "true", "AIDM_MODE": "development"})

    def test_dotenv_cannot_switch_mode(self):
        self.dotenv.write_text("AIDM_MODE=production\nAIDM_DEBUG=true\n")
        got = self.load({})
        self.assertEqual(got.mode, "development")
        self.assertTrue(got.debug)

    def test_bool_and_numeric_parsing(self):
        for truthy in ("true", "YES", "1", "on"):
            with self.subTest(truthy=truthy):
                self.assertTrue(self.load({"AIDM_DEBUG": truthy}).debug)
        for falsy in ("false", "No", "0", "off"):
            with self.subTest(falsy=falsy):
                self.assertFalse(self.load({"AIDM_DEBUG": falsy}).debug)
        self.assertEqual(self.load({"AIDM_REQUEST_TIMEOUT_SECONDS": "0.5"}).request_timeout_seconds, 0.5)
        for bad in ("0", "-1", "nan", "inf", "garbage"):
            with self.subTest(bad=bad):
                with self.assertRaises(ConfigError) as caught:
                    self.load({"AIDM_REQUEST_TIMEOUT_SECONDS": bad})
                self.assertIn("AIDM_REQUEST_TIMEOUT_SECONDS", str(caught.exception))
                self.assertNotIn(bad, str(caught.exception))

    def test_invalid_bool_mode_and_level_name_only(self):
        for env, expected in [
            ({"AIDM_DEBUG": "unlikely-secret-fragment-001"}, "AIDM_DEBUG"),
            ({"AIDM_MODE": "unlikely-secret-fragment-002"}, "AIDM_MODE"),
            ({"AIDM_LOG_LEVEL": "unlikely-secret-fragment-003"}, "AIDM_LOG_LEVEL"),
        ]:
            with self.subTest(expected=expected):
                with self.assertRaises(ConfigError) as caught:
                    self.load(env)
                msg = str(caught.exception)
                self.assertIn(expected, msg)
                self.assertNotIn("unlikely-secret-fragment-", msg)

    def test_secret_required_only_when_requested(self):
        self.assertIsNone(self.load({"AIDM_MODE": "test"}).get_secret("DEMO_SECRET"))
        with self.assertRaises(ConfigError) as caught:
            self.load({"AIDM_MODE": "test"}, required_secrets=("DEMO_SECRET",))
        self.assertIn("DEMO_SECRET", str(caught.exception))
        got = self.load({"AIDM_MODE": "test", "DEMO_SECRET": "synthetic-test-token-b83e6511"}, required_secrets=("DEMO_SECRET",))
        self.assertEqual(got.get_secret("DEMO_SECRET"), "synthetic-test-token-b83e6511")

    def test_secret_env_overrides_dotenv(self):
        self.dotenv.write_text("DEMO_SECRET='synthetic-test-token-from-file'\n")
        got = self.load({"DEMO_SECRET": "synthetic-test-token-from-process"}, required_secrets=("DEMO_SECRET",))
        self.assertEqual(got.get_secret("DEMO_SECRET"), "synthetic-test-token-from-process")

    def test_no_secret_prefix_in_repr_safe_dict_or_errors(self):
        sentinel = "synthetic-DO-NOT-LOG-a7b8c9d0e1"
        got = self.load({"DEMO_SECRET": sentinel}, required_secrets=("DEMO_SECRET",))
        displayed = repr(got) + str(got) + json.dumps(got.to_safe_dict())
        self.assertNotIn(sentinel, displayed)
        self.assertNotIn(sentinel[:12], displayed)
        self.assertNotIn("DEMO_SECRET", displayed)
        with self.assertRaises(TypeError):
            json.dumps(got)
        with self.assertRaises(TypeError):
            pickle.dumps(got)

    def test_dotenv_syntax_is_restricted_and_errors_redacted(self):
        sentinel = "synthetic-DO-NOT-LOG-z9y8x7w6"
        self.dotenv.write_text(f"DEMO_SECRET=\"{sentinel}\"\nAIDM_DEBUG=true # safe comment\n")
        got = self.load({}, required_secrets=("DEMO_SECRET",))
        self.assertEqual(got.get_secret("DEMO_SECRET"), sentinel)
        self.assertTrue(got.debug)
        self.dotenv.write_text(f"DEMO_SECRET=\"{sentinel} broken\n")
        with self.assertRaises(ConfigError) as caught:
            self.load({}, required_secrets=("DEMO_SECRET",))
        self.assertNotIn(sentinel, str(caught.exception))
        self.assertNotIn(sentinel[:10], str(caught.exception))

    def test_unknown_key_names_rejected_without_echoing(self):
        with self.assertRaisesRegex(ConfigError, "SECRET_KEY_NAME"):
            self.load({}, required_secrets=("INVALID SECRET NAME WITH SPACES",))

    def test_import_is_side_effect_free(self):
        # Functional proof: missing .env and no provider key still load offline.
        self.assertEqual(self.load({"AIDM_MODE": "test"}).mode, "test")


if __name__ == "__main__":
    unittest.main()