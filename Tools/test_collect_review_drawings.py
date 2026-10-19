import base64
import json
import tempfile
import unittest
from pathlib import Path

from collect_review_drawings import collect


class SavedDrawingEvidenceTests(unittest.TestCase):
    def test_collects_persistent_margin_without_modifying_source(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "app"
            page = root / "Documents/notebook-margins/page.json"
            page.parent.mkdir(parents=True)
            drawing = b"saved native drawing bytes"
            original = json.dumps({"ink": base64.b64encode(drawing).decode(),
                                   "width": 650, "height": 900}).encode()
            page.write_bytes(original)
            output = Path(temporary) / "evidence"
            report = collect(root, output)
            self.assertEqual(len(report["drawings"]), 1)
            self.assertEqual((output / report["drawings"][0]["drawing"]).read_bytes(), drawing)
            self.assertEqual(page.read_bytes(), original)
            self.assertEqual(report["drawings"][0]["source"], "Documents/notebook-margins/page.json")

    def test_does_not_copy_a_margin_symlink_outside_app(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "app"
            folder = root / "Documents/notebook-margins"
            folder.mkdir(parents=True)
            outside = Path(temporary) / "outside.json"
            outside.write_text(json.dumps({"ink": base64.b64encode(b"outside").decode()}))
            (folder / "page.json").symlink_to(outside)
            report = collect(root, Path(temporary) / "evidence")
            self.assertEqual(report["drawings"], [])
