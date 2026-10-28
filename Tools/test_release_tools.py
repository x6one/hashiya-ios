"""Regression checks for native release numbering and Apple's acceptance gate."""
import json
import glob
import plistlib
import subprocess
import tempfile
import unittest
from contextlib import chdir
from pathlib import Path
from unittest.mock import patch

import yaml
import distribute_native_app
from distribute_native_app import run_apple, validate_release_version
from prepare_native_office_app import prepare
from package_native_app import package


class ReleaseToolsTests(unittest.TestCase):
    def test_exported_encryption_classification_matches_the_audited_project(self):
        spec = {"settings": {"base": {"MARKETING_VERSION": "0.6.0", "CURRENT_PROJECT_VERSION": "14"}},
                "targets": {"Hashiya": {"info": {"properties": {"ITSAppUsesNonExemptEncryption": False}}}}}
        info = {"CFBundleShortVersionString": "0.6.0", "CFBundleVersion": "14",
                "ITSAppUsesNonExemptEncryption": False}
        validate_release_version(info, spec)
        for replacement in [None, True, "false", 0]:
            with self.subTest(replacement=replacement):
                rejected = {**info}
                if replacement is None:
                    rejected.pop("ITSAppUsesNonExemptEncryption")
                else:
                    rejected["ITSAppUsesNonExemptEncryption"] = replacement
                with self.assertRaisesRegex(RuntimeError, "ITSAppUsesNonExemptEncryption"):
                    validate_release_version(rejected, spec)

    def test_nested_qa_checkout_does_not_shadow_source_on_macos(self):
        workflow = yaml.safe_load(Path('.github/workflows/tayya-testflight-candidate.yml').read_text())
        source_names = {name.casefold() for name in ['App', 'Tools', 'Tests', 'UITests', 'NativeOffice', 'Store']}
        for step in workflow['jobs']['qa-candidate']['steps']:
            if step.get('uses') == 'actions/checkout@v4':
                destination = step.get('with', {}).get('path')
                if destination:
                    self.assertNotIn(Path(destination).parts[0].casefold(), source_names,
                                     'macOS checkout must not replace App through case-insensitive app alias')

    def test_internal_qa_push_requires_exact_branch_and_explicit_owner_marker(self):
        workflow = yaml.safe_load(Path('.github/workflows/tayya-testflight-candidate.yml').read_text())
        triggers = workflow.get('on', workflow.get(True))
        self.assertEqual(triggers.get('push', {}).get('branches'), ['integration/tayya-app-store'])
        job = workflow['jobs']['qa-candidate']
        expression = job['if'].strip().removeprefix('${{').removesuffix('}}').strip()
        for event, ref, message, allowed in [
                ('push', 'integration/tayya-app-store', '[testflight:internal]', True),
                ('push', 'integration/tayya-app-store', 'test: repair UI helper', False),
                ('push', 'main', '[testflight:internal]', False),
                ('push', 'integration/other', '[testflight:internal]', False),
                ('workflow_dispatch', 'integration/tayya-app-store', '', True),
                ('pull_request', 'integration/tayya-app-store', '[testflight:internal]', False)]:
            with self.subTest(event=event, ref=ref, message=message):
                condition = expression.replace('github.repository', repr('x6one/hashiya-ios'))
                condition = condition.replace('github.ref', repr('refs/heads/' + ref))
                condition = condition.replace('github.event_name', repr(event))
                condition = condition.replace('github.event.head_commit.message', repr(message))
                condition = condition.replace('&&', ' and ').replace('||', ' or ')
                self.assertEqual(eval(condition, {'__builtins__': {}}, {'contains': lambda s, t: t in s}), allowed)
        self.assertEqual(job['env']['APP_SOURCE'], '${{ inputs.app_source || github.sha }}')

    def test_store_capture_requires_an_explicit_capture_request(self):
        workflow = yaml.safe_load(Path('.github/workflows/tayya-store-assets.yml').read_text())
        expression = workflow['jobs']['medium-phone']['if'].strip().removeprefix('${{').removesuffix('}}').strip()
        for event, capture, message, allowed in [
                ('push', False, 'ci: prepare QA tooling', False),
                ('push', False, '[store:readiness]', False),
                ('push', False, '[store:captures]', True),
                ('workflow_dispatch', False, '', False),
                ('workflow_dispatch', True, '', True)]:
            with self.subTest(event=event, capture=capture, message=message):
                condition = expression.replace('github.event_name', repr(event))
                condition = condition.replace('github.event.head_commit.message', repr(message))
                condition = condition.replace('inputs.capture', repr(capture)).replace('&&', ' and ').replace('||', ' or ')
                condition = condition.replace('!contains', 'not contains')
                result = eval(condition, {'__builtins__': {}}, {'contains': lambda text, needle: needle in text})
                self.assertEqual(result, allowed, 'Readiness/tooling updates must not start native capture tests')

    def test_qa_artifacts_exclude_an_export_rejected_before_verification(self):
        workflow = yaml.safe_load(Path('.github/workflows/tayya-testflight-candidate.yml').read_text())
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for name in ['AppleDistribution/Export/rejected.ipa', 'AppleDistribution/Tayya-QA.xcarchive.zip',
                         'UnsignedCandidate/rejected.ipa', 'QA/Verified/accepted.ipa',
                         'QA/source.json', 'private/signing-key.p8']:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b'fixture')
            selected = set()
            for step in workflow['jobs']['qa-candidate']['steps']:
                if step.get('uses') != 'actions/upload-artifact@v4':
                    continue
                for pattern in step['with']['path'].splitlines():
                    for match in glob.glob(str(root / pattern.strip())):
                        path = Path(match)
                        selected.update(path.rglob('*') if path.is_dir() else [path])
            self.assertNotIn(root / 'AppleDistribution/Export/rejected.ipa', selected,
                             'A failed codesign/resource check must not publish the raw exported IPA')
            self.assertNotIn(root / 'AppleDistribution/Tayya-QA.xcarchive.zip', selected)
            self.assertNotIn(root / 'private/signing-key.p8', selected)
            self.assertNotIn(root / 'UnsignedCandidate/rejected.ipa', selected)
            self.assertIn(root / 'QA/Verified/accepted.ipa', selected)

    def test_archive_retention_requires_both_explicit_request_and_verified_output(self):
        cleanup = getattr(distribute_native_app, "cleanup_archive", None)
        self.assertTrue(callable(cleanup), "The distribution helper needs explicit verified archive retention")
        for preserve, verified in [(False, False), (False, True), (True, False), (True, True)]:
            with self.subTest(preserve=preserve, verified=verified), tempfile.TemporaryDirectory() as folder:
                archive = Path(folder) / "Tayya.xcarchive"
                archive.mkdir()
                marker = archive / "verified-binary"
                marker.write_bytes(b"original archive bytes")
                cleanup(archive, preserve=preserve, verified=verified)
                self.assertEqual(archive.exists(), preserve and verified)
                if archive.exists():
                    self.assertEqual(marker.read_bytes(), b"original archive bytes")

    def test_privacy_manifest_declares_app_owned_preference_storage(self):
        manifest = plistlib.loads(Path("App/Resources/PrivacyInfo.xcprivacy").read_bytes())
        reasons = {item["NSPrivacyAccessedAPIType"]: item["NSPrivacyAccessedAPITypeReasons"]
                   for item in manifest["NSPrivacyAccessedAPITypes"]}
        self.assertIn("CA92.1", reasons.get("NSPrivacyAccessedAPICategoryUserDefaults", []),
                      "Persisted pen, reading and language preferences require the app-owned UserDefaults declaration")

    def test_unsigned_package_rejects_stale_version_build_or_other_bundle(self):
        spec = yaml.safe_load(Path("project.yml").read_text())
        settings = spec["settings"]["base"]
        valid = {"CFBundleShortVersionString": str(settings["MARKETING_VERSION"]),
                 "CFBundleVersion": str(settings["CURRENT_PROJECT_VERSION"]),
                 "CFBundleIdentifier": "com.ahmadalawi.hashiya",
                 "CFBundleExecutable": "Hashiya", "UIDeviceFamily": [1, 2],
                 "ITSAppUsesNonExemptEncryption": False}
        for key, wrong in [("CFBundleShortVersionString", "0.5.0"),
                           ("CFBundleVersion", "12"),
                           ("CFBundleIdentifier", "com.example.other")]:
            with self.subTest(field=key), tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                app = root / "Hashiya.app"
                app.mkdir()
                (app / "Info.plist").write_bytes(plistlib.dumps({**valid, key: wrong}))
                with patch("package_native_app.subprocess.run") as native, \
                     patch("package_native_app.subprocess.check_output", return_value="platform IOS\n"):
                    with self.assertRaisesRegex(RuntimeError, key):
                        package(app, root / "output")
                    native.assert_not_called()
                self.assertFalse((root / "output").exists())

    def test_unsigned_package_uses_own_checkout_from_engine_working_folder(self):
        spec = yaml.safe_load(Path("project.yml").read_text())
        settings = spec["settings"]["base"]
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            app = root / "Hashiya.app"
            app.mkdir()
            (app / "Info.plist").write_bytes(plistlib.dumps({
                "CFBundleShortVersionString": str(settings["MARKETING_VERSION"]),
                "CFBundleVersion": str(settings["CURRENT_PROJECT_VERSION"]),
                "CFBundleIdentifier": "com.ahmadalawi.hashiya",
                "CFBundleExecutable": "Hashiya", "UIDeviceFamily": [1, 2],
                 "ITSAppUsesNonExemptEncryption": False}))
            # The engine checkout must not decide the application release.
            (root / "project.yml").write_text("settings: {base: {MARKETING_VERSION: '9.0', CURRENT_PROJECT_VERSION: '99'}}")
            with chdir(root), patch("package_native_app.subprocess.run",
                                    side_effect=RuntimeError("native validation reached")) as native:
                with self.assertRaisesRegex(RuntimeError, "native validation reached"):
                    package(app, root / "output")
                self.assertEqual(native.call_args.args[0][:2], ["xcrun", "lipo"])
                native.assert_called_once()
            self.assertFalse((root / "output").exists())

    def test_engine_preparation_preserves_canonical_version(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            candidate, report = root / "candidate", root / "report"
            candidate.mkdir()
            report.mkdir()
            (candidate / "manifest.json").write_text(json.dumps({"source": "pinned"}))
            (report / "link-report.json").write_text(json.dumps({"source": "pinned", "linked": True}))
            project = root / "project.yml"
            spec = yaml.safe_load(Path("project.yml").read_text())
            spec["settings"]["base"].update(MARKETING_VERSION="9.2.1", CURRENT_PROJECT_VERSION="99")
            project.write_text(yaml.safe_dump(spec))
            generated = json.loads(prepare(candidate, report, project).read_text())
            self.assertEqual(generated["settings"]["base"]["MARKETING_VERSION"], "9.2.1")
            self.assertEqual(generated["settings"]["base"]["CURRENT_PROJECT_VERSION"], "99")

    def test_exported_version_must_match_project(self):
        spec = {"settings": {"base": {"MARKETING_VERSION": "0.4.0", "CURRENT_PROJECT_VERSION": "8"}}}
        validate_release_version({"CFBundleShortVersionString": "0.4.0", "CFBundleVersion": "8"}, spec)
        for version, build in [("0.3.0", "8"), ("0.4.0", "7")]:
            with self.assertRaises(RuntimeError):
                validate_release_version({"CFBundleShortVersionString": version, "CFBundleVersion": build}, spec)

    def test_zero_exit_with_apple_errors_is_rejected(self):
        result = subprocess.CompletedProcess([], 0, plistlib.dumps({"product-errors": [{"code": -19232}]}), b"")
        with patch("distribute_native_app.subprocess.run", return_value=result), self.assertRaises(RuntimeError):
            run_apple(["xcrun", "altool"], "Upload", env={})

    def test_missing_or_invalid_success_response_is_rejected(self):
        for output in [b"", b"not a plist", plistlib.dumps({})]:
            result = subprocess.CompletedProcess([], 0, output, b"")
            with patch("distribute_native_app.subprocess.run", return_value=result), self.assertRaises(RuntimeError):
                run_apple(["xcrun", "altool"], "Upload", env={})

    def test_structured_success_requires_no_error_or_failed_exit(self):
        output = plistlib.dumps({"success-message": "No errors uploading package."})
        for code, stderr in [(1, b""), (0, b"ERROR: rejected")]:
            result = subprocess.CompletedProcess([], code, output, stderr)
            with patch("distribute_native_app.subprocess.run", return_value=result), self.assertRaises(RuntimeError):
                run_apple(["xcrun", "altool"], "Upload", env={})
        result = subprocess.CompletedProcess([], 0, output, b"")
        with patch("distribute_native_app.subprocess.run", return_value=result):
            run_apple(["xcrun", "altool"], "Upload", env={})


if __name__ == "__main__":
    unittest.main()
