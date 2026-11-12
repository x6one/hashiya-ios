import base64
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

from restore_approved_design import restore


class ApprovedDesignRestoreTests(unittest.TestCase):
    def archive(self, root, *, source=None, file='images/approved-design-001.png', altered=False):
        # Tiny test-only PNG; never used as application review evidence.
        pixels = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=')
        row = dict(file=file, source=source or 'e94c2cbb6f6914e0ebb21ded090beaa54013e4df',
                   logical_name='Light-document-Portrait', scene='Editor', family='iPhone', orientation='portrait',
                   font_size='default', color_mode='light', language='ar', device='test fixture',
                   sha256=hashlib.sha256(pixels).hexdigest(),
                   test_url='https://github.com/x6one/hashiya-ios/actions/runs/39491602063/job/1')
        path = root / 'review.zip'
        with zipfile.ZipFile(path, 'w') as zipped:
            zipped.writestr('Tayya-Production-Review/captures.json', json.dumps([dict(before=row, after=None)]))
            zipped.writestr('Tayya-Production-Review/' + file, b'altered' if altered else pixels)
        return path, row, pixels

    def test_recovers_original_bytes_and_provenance_without_relabeling_source(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); archive, row, pixels = self.archive(root)
            output = root / 'approved'
            self.assertEqual(restore(archive, output), 1)
            rows = json.loads((output / 'all-images.json').read_text())
            self.assertEqual(rows, [row])
            self.assertEqual((output / row['file']).read_bytes(), pixels)

    def test_tampered_pixels_are_rejected_before_creating_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); archive, _, _ = self.archive(root, altered=True)
            output = root / 'approved'
            with self.assertRaisesRegex(ValueError, 'hash'):
                restore(archive, output)
            self.assertFalse(output.exists())

    def test_unapproved_source_and_escaping_path_are_rejected(self):
        for options, error in [(dict(source='a' * 40), 'source'), (dict(file='../escape.png'), 'path')]:
            with self.subTest(options=options), tempfile.TemporaryDirectory() as directory:
                root = Path(directory); archive, _, _ = self.archive(root, **options)
                output = root / 'approved'
                with self.assertRaisesRegex(ValueError, error):
                    restore(archive, output)
                self.assertFalse(output.exists())
