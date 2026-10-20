"""Offline artifact contracts, independent of macOS or simulator execution."""
import hashlib
import importlib.util
import json
import pathlib
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('gallery', pathlib.Path(__file__).with_name('build_review_gallery.py'))
gallery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gallery)


class ReviewGalleryTests(unittest.TestCase):
    def fixture(self, root, folder, sha, payload):
        for family in ['iPhone', 'iPad']:
            evidence = root / folder / family
            (evidence / 'Screenshots').mkdir(parents=True)
            image = evidence / 'Screenshots/page.png'
            image.write_bytes(payload + family.encode())
            (evidence / 'source.json').write_text(json.dumps({'source': sha, 'family': family, 'images': [
                {'file': 'Screenshots/page.png', 'sha256': hashlib.sha256(image.read_bytes()).hexdigest()}]}))
            (evidence / 'Screenshots/manifest.json').write_text(json.dumps([{'testIdentifier': 'capture', 'attachments': [
                {'exportedFileName': 'page.png', 'suggestedHumanReadableName': 'Studio-Light-document-Portrait_0_1.png'}]}]))

    def test_comparison_retains_old_and_new_original_bytes_and_provenance(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            self.fixture(root, 'baseline', 'old-sha', b'old')
            self.fixture(root, 'polish', 'new-sha', b'new')
            plan = root / 'plan.json'
            plan.write_text(json.dumps({'sources': [{'folder': 'baseline', 'sha': 'old-sha', 'run': 1},
                                                   {'folder': 'polish', 'sha': 'new-sha', 'run': 2}]}))
            output = root / 'review'
            gallery.build(root, output, plan)
            self.assertTrue((output / 'compare.html').exists(), 'Review artifact must provide an old/new comparison')
            comparison = (output / 'compare.html').read_text()
            self.assertIn('old-sha', comparison)
            self.assertIn('new-sha', comparison)
            records = json.loads((output / 'all-images.json').read_text())
            self.assertEqual(len(records), 4)
            for record in records:
                self.assertEqual(hashlib.sha256((output / record['file']).read_bytes()).hexdigest(), record['sha256'])

    def test_explicit_review_references_take_precedence_over_intermediate_images(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            self.fixture(root, 'baseline', 'original-review-sha', b'original')
            self.fixture(root, 'repair', 'intermediate-sha', b'intermediate')
            self.fixture(root, 'polish', 'polished-sha', b'new')
            plan = root / 'plan.json'
            plan.write_text(json.dumps({'sources': [
                {'folder': 'baseline', 'sha': 'original-review-sha', 'run': 1},
                {'folder': 'repair', 'sha': 'intermediate-sha', 'run': 2},
                {'folder': 'polish', 'sha': 'polished-sha', 'run': 3}],
                'reference_images': ['001-iPad.png', '002-iPhone.png']}))
            output = root / 'review'
            gallery.build(root, output, plan)
            comparison = (output / 'compare.html').read_text()
            self.assertIn('original-review-sha', comparison)
            self.assertNotIn('intermediate-sha', comparison)
            self.assertEqual(len(json.loads((output / 'all-images.json').read_text())), 6)

    def test_tampered_original_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            self.fixture(root, 'baseline', 'old-sha', b'old')
            (root / 'baseline/iPhone/Screenshots/page.png').write_bytes(b'tampered')
            plan = root / 'plan.json'
            plan.write_text(json.dumps({'sources': [{'folder': 'baseline', 'sha': 'old-sha', 'run': 1}]}))
            with self.assertRaises(AssertionError):
                gallery.build(root, root / 'review', plan)

    def test_real_pdf_picker_capture_is_paired_with_original_picker_reference(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            self.fixture(root, 'baseline', 'original-picker-sha', b'old')
            self.fixture(root, 'polish', 'real-picker-sha', b'new')
            for folder, scene in [('baseline', 'Document-PageThumbnails'), ('polish', 'Polish-Real-PageThumbnails')]:
                for family in ['iPhone', 'iPad']:
                    manifest = root / folder / family / 'Screenshots/manifest.json'
                    content = json.loads(manifest.read_text())
                    content[0]['attachments'][0]['suggestedHumanReadableName'] = 'Studio-' + scene + '_0_1.png'
                    manifest.write_text(json.dumps(content))
            plan = root / 'plan.json'
            plan.write_text(json.dumps({'sources': [
                {'folder': 'baseline', 'sha': 'original-picker-sha', 'run': 1},
                {'folder': 'polish', 'sha': 'real-picker-sha', 'run': 2}],
                'reference_images': ['001-iPad.png', '002-iPhone.png']}))
            output = root / 'review'
            gallery.build(root, output, plan)
            comparison = (output / 'compare.html').read_text()
            self.assertIn('original-picker-sha', comparison, 'The real picker must compare against the user’s original picker reference')
            self.assertIn('real-picker-sha', comparison)


if __name__ == '__main__':
    unittest.main()
