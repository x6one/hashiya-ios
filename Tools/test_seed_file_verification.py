import contextlib
import io
import os
from pathlib import Path
import runpy
import sys
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]


class OwnedFixtureVerificationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.app = self.root / "app"
        self.documents = self.app / "Documents"
        self.documents.mkdir(parents=True)
        self.provider = self.root / "provider"
        self.provider_files = self.provider / "File Provider Storage"
        self.provider_files.mkdir(parents=True)
        fixtures = list((ROOT / "App").rglob("english.pdf"))
        self.assertEqual(len(fixtures), 1)
        self.original = fixtures[0].read_bytes()

    def verify(self):
        def container(command, **_):
            if command[-2:] == ["com.apple.DocumentsApp", "groups"]:
                return "group.com.apple.FileProvider.LocalStorage: " + str(self.provider) + "\n"
            if command[-2:] == ["com.ahmadalawi.hashiya", "data"]:
                return str(self.app) + "\n"
            self.fail("Unexpected native command: " + repr(command))

        with contextlib.chdir(ROOT), contextlib.redirect_stdout(io.StringIO()):
            with patch.dict(os.environ, {"SIMULATOR_ID": "TEST-SIM"}):
                with patch.object(sys, "argv", ["seed_files_fixtures.py", "--verify-owned"]):
                    with patch("subprocess.check_output", side_effect=container):
                        with patch("subprocess.run") as mutation:
                            runpy.run_path(str(ROOT / "Tools/seed_files_fixtures.py"), run_name="__main__")
                            mutation.assert_not_called()

    def test_owned_verification_reads_the_retained_app_source_without_launching_files(self):
        source = self.documents / "Owned-fixture.pdf"
        source.write_bytes(self.original)
        self.verify()
        self.assertEqual(source.read_bytes(), self.original)

    def test_owned_verification_rejects_changed_source_bytes(self):
        source = self.documents / "Owned-fixture.pdf"
        source.write_bytes(b"changed after import")
        with self.assertRaisesRegex(RuntimeError, "bytes differ"):
            self.verify()
        self.assertEqual(source.read_bytes(), b"changed after import")

    def test_a_file_outside_the_app_folder_cannot_satisfy_owned_verification(self):
        (self.provider_files / "Owned-fixture.pdf").write_bytes(self.original)
        with self.assertRaisesRegex(RuntimeError, "Expected exactly one native export"):
            self.verify()


if __name__ == "__main__":
    unittest.main()
