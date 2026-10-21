import json
from pathlib import Path
import tempfile
import unittest

from Tools import test_integration_captures as capture_tests
from Tools.assemble_production_review import approved_scenes, production_scenes


class ProductionReviewTests(unittest.TestCase):
    def test_approved_context_maps_only_known_screens_from_approved_source(self):
        source = 'e94c2cbb6f6914e0ebb21ded090beaa54013e4df'
        common = dict(source=source, family='iPhone', orientation='portrait', font_size='default', color_mode='light', language='ar')
        rows = [dict(common, logical_name='Light-document-Portrait'),
                dict(common, logical_name='Polish-Pen-Context'),
                dict(common, logical_name='Polish-Text-Context'),
                dict(common, logical_name='Light-document-Portrait', source='a' * 40)]
        result = approved_scenes(rows)
        self.assertEqual([r['scene'] for r in result], ['Editor', 'Pen-Tools'])
        self.assertEqual(result[0]['font_size'], 'default')
        self.assertEqual(result[0]['source'], source)

    def test_real_test_job_and_staged_source_must_match_before_indexing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            family = root / 'production-captures-iPhone'; family.mkdir()
            capture_tests.NativeCaptureIndexTests().fixture(family)
            proof = dict(source='a' * 40, family='iPhone', run=123)
            (family / 'provenance.json').write_text(json.dumps(proof))
            jobs = [dict(name='focused (iPhone)', id=456, run_id=123, conclusion='success', status='completed')]
            rows = production_scenes(root, 'a' * 40, 123, jobs, 'focused', families=('iPhone',))
            self.assertEqual(rows[0]['file'], 'production-captures-iPhone/Screenshots/native.png')
            self.assertTrue(rows[0]['test_url'].endswith('/123/job/456'))
            proof['source'] = 'b' * 40
            (family / 'provenance.json').write_text(json.dumps(proof))
            with self.assertRaisesRegex(ValueError, 'provenance'):
                production_scenes(root, 'a' * 40, 123, jobs, 'focused', families=('iPhone',))
            proof['source'] = 'a' * 40
            (family / 'provenance.json').write_text(json.dumps(proof))
            jobs[0]['conclusion'] = 'failure'
            with self.assertRaisesRegex(ValueError, 'passing'):
                production_scenes(root, 'a' * 40, 123, jobs, 'focused', families=('iPhone',))

    def test_duplicate_approved_context_uses_its_explicit_final_capture_contract(self):
        common = dict(source='e94c2cbb6f6914e0ebb21ded090beaa54013e4df', family='iPhone',
                      orientation='portrait', font_size='default', color_mode='light', language='ar')
        rows = [dict(common, logical_name='Light-document-Portrait', test='StudioCaptureTests/testCapturePrimaryScenesLight()'),
                dict(common, logical_name='Light-document-Portrait', test='StudioCaptureTests/testUpdatedDocumentTextRendering()'),
                dict(common, logical_name='Document-Focus', test='StudioCaptureTests/testRecordingNavigationMarkersAndFocusStayIndependent()'),
                dict(common, logical_name='Final-Light-Focus-Portrait', test='StudioCaptureTests/testFinalPolishExpandedNotesAndFocusCaptures()'),
                dict(common, logical_name='Document-PageThumbnails', test='StudioCaptureTests/testPagePickerAndFlashcardReveal()'),
                dict(common, logical_name='Document-PageThumbnails', test='StudioCaptureTests/testPolishPickerUsesRealPageThumbnails()')]
        result = approved_scenes(rows)
        self.assertEqual(len(result), 3)
        self.assertTrue(result[0]['test'].endswith('testUpdatedDocumentTextRendering()'))
        self.assertTrue(result[1]['logical_name'].startswith('Final-'))
        self.assertTrue(result[2]['test'].endswith('testPolishPickerUsesRealPageThumbnails()'))
