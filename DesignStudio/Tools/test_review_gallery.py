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

    def plan(self, root, strict=False):
        path = root / 'plan.json'
        path.write_text(json.dumps({'sources': [
            {'folder': 'baseline', 'sha': 'old', 'run': 1},
            {'folder': 'polish', 'sha': 'new', 'run': 2, 'require_native_metadata': strict,
             'jobs': {'iPhone': 20, 'iPad': 21}}]}))
        return path

    def native_metadata(self, root):
        for family in ['iPhone', 'iPad']:
            evidence = root / 'polish' / family
            manifest = evidence / 'Screenshots/manifest.json'
            data = json.loads(manifest.read_text())
            data[0]['attachments'].append({'exportedFileName': 'traits.json', 'suggestedHumanReadableName': 'Studio-Metadata-document.json'})
            manifest.write_text(json.dumps(data))
            (evidence / 'Screenshots/traits.json').write_text(json.dumps({
                'screen': 'Light-document-Portrait', 'orientation': 'landscape', 'font_size': 'AX5',
                'color_mode': 'dark', 'language': 'en', 'metadata_origin': 'native capture arguments and window'}))
            (evidence / 'summary.json').write_text(json.dumps({'devicesAndConfigurations': [
                {'device': {'deviceName': family + ' actual model', 'osVersion': '26.2'}}]}))

    def test_captions_include_full_source_device_and_test_traits(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            self.fixture(root, 'baseline', 'old', b'old')
            self.fixture(root, 'polish', 'new', b'new')
            output = root / 'review'
            gallery.build(root, output, self.plan(root))
            for page in ['index.html', 'compare.html']:
                text = (output / page).read_text()
                for value in ['portrait', 'default', 'light', 'ar', 'capture', 'new', '/job/20']:
                    self.assertIn(value, text)

    def test_fresh_capture_without_native_sidecar_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            self.fixture(root, 'baseline', 'old', b'old')
            self.fixture(root, 'polish', 'new', b'new')
            with self.assertRaisesRegex(ValueError, 'Missing native capture metadata'):
                gallery.build(root, root / 'review', self.plan(root, strict=True))

    def test_native_metadata_overrides_legacy_filename_inference(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            self.fixture(root, 'baseline', 'old', b'old')
            self.fixture(root, 'polish', 'new', b'new')
            self.native_metadata(root)
            output = root / 'review'
            gallery.build(root, output, self.plan(root, strict=True))
            records = [r for r in json.loads((output / 'all-images.json').read_text()) if r['source'] == 'new']
            self.assertEqual(len(records), 2)
            for record in records:
                self.assertEqual((record['orientation'], record['font_size'], record['color_mode'], record['language']),
                                 ('landscape', 'AX5', 'dark', 'en'))
                self.assertIn('actual model', record['device'])
                self.assertEqual(record['os_version'], '26.2')

    def test_final_index_does_not_mix_unmatched_historical_scenes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            self.fixture(root, 'baseline', 'old', b'old')
            self.fixture(root, 'polish', 'new', b'new')
            for manifest in (root / 'baseline').rglob('manifest.json'):
                content = json.loads(manifest.read_text())
                content[0]['attachments'][0]['suggestedHumanReadableName'] = 'Studio-Historical-Only_0_x.png'
                manifest.write_text(json.dumps(content))
            output = root / 'review'
            gallery.build(root, output, self.plan(root))
            self.assertNotIn('Historical-Only', (output / 'index.html').read_text())
            self.assertIn('Historical-Only', (output / 'history.html').read_text())
            self.assertNotIn('تعرض هذه الصفحة صور مصدر الاعتماد الحالي فقط', (output / 'history.html').read_text())

    def test_native_diverse_pdf_is_preserved_with_hash_and_source(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            self.fixture(root, 'baseline', 'old', b'old')
            self.fixture(root, 'polish', 'new', b'new')
            for family in ['iPhone', 'iPad']:
                folder = root / 'polish' / family / 'Screenshots'
                (folder / 'native.pdf').write_bytes(b'%PDF-original-native-bytes')
                manifest = folder / 'manifest.json'
                data = json.loads(manifest.read_text())
                data[0]['attachments'].append({'exportedFileName': 'native.pdf', 'suggestedHumanReadableName': 'Studio-Diverse-Native-PDF_0_x.pdf'})
                manifest.write_text(json.dumps(data))
            output = root / 'review'
            gallery.build(root, output, self.plan(root))
            records = json.loads((output / 'documents.json').read_text())
            self.assertEqual(len(records), 2)
            for record in records:
                self.assertEqual((output / record['file']).read_bytes(), b'%PDF-original-native-bytes')
                self.assertEqual(record['source'], 'new')
                self.assertEqual(hashlib.sha256((output / record['file']).read_bytes()).hexdigest(), record['sha256'])

    def test_final_package_rejects_failed_or_skipped_native_gate(self):
        for failure in [{'failedTests': 1, 'skippedTests': 0}, {'failedTests': 0, 'skippedTests': 1}]:
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as directory:
                root = pathlib.Path(directory)
                self.fixture(root, 'baseline', 'old', b'old')
                self.fixture(root, 'polish', 'new', b'new')
                self.native_metadata(root)
                plan = self.plan(root, strict=True)
                data = json.loads(plan.read_text())
                data['sources'][1]['required_test_count'] = 46
                plan.write_text(json.dumps(data))
                for summary in (root / 'polish').rglob('summary.json'):
                    value = json.loads(summary.read_text())
                    value.update({'passedTests': 45, 'expectedFailures': 0, **failure})
                    summary.write_text(json.dumps(value))
                with self.assertRaisesRegex(ValueError, 'Incomplete native approval gate'):
                    gallery.build(root, root / 'review', plan)


if __name__ == '__main__':
    unittest.main()
