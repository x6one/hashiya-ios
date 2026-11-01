"""Exercise the real release-artifact and source-attribution boundaries."""
import hashlib
import copy
import io
import json
import os
import subprocess
import tarfile
import tempfile
import unittest
import zipfile
from pathlib import Path

import store_release
from store_release import extract_engine, verify_listing, write_provenance, verify_authorization


class StoreReleaseTests(unittest.TestCase):
    def test_official_build_inspection_is_read_only_and_separate_from_upload(self):
        import yaml
        workflow = yaml.safe_load(Path('.github/workflows/tayya-store-listing.yml').read_text())
        self.assertIn('inspect-build-number', list(workflow['jobs']))
        job = workflow['jobs']['inspect-build-number']
        expression = job['if'].strip().removeprefix('${{').removesuffix('}}').strip()
        for branch, marker, permitted in [
                ('store/tayya-app-store-content', '[store:inspect-build]', True),
                ('main', '[store:inspect-build]', False),
                ('store/tayya-app-store-content', '[store:publish-approved]', False)]:
            condition = expression.replace('github.repository', repr('x6one/hashiya-ios'))
            condition = condition.replace('github.ref', repr('refs/heads/' + branch))
            condition = condition.replace('github.event_name', repr('push'))
            condition = condition.replace('github.event.head_commit.message', repr(marker)).replace('&&', ' and ').replace('||', ' or ')
            self.assertEqual(eval(condition, {'__builtins__': {}}, {'contains': lambda s, t: t in s}), permitted)
        commands = '\n'.join(s.get('run', '') for s in job['steps'])
        self.assertIn('node Tools/testflight_candidate.mjs select OfficialBuildSelection.json', commands)
        for forbidden in ['xcodebuild ', 'distribute_native_app.py', 'submit_store_review.mjs', 'testflight_candidate.mjs assign', 'testflight_candidate.mjs complete']:
            self.assertNotIn(forbidden, commands)

    def test_photographed_configuration_allows_only_build_metadata_and_proven_encryption_declaration(self):
        import yaml
        prior = yaml.safe_load(Path('project.yml').read_text())
        candidate = copy.deepcopy(prior)
        candidate['settings']['base']['CURRENT_PROJECT_VERSION'] = '14'
        candidate['targets']['Hashiya']['info']['properties']['ITSAppUsesNonExemptEncryption'] = False
        config = {**self.config, 'build': '14', 'app_tree': '3bfde5b48db135649378d14e42c5654cc1a0d8c6'}
        evidence = json.loads(Path('Store/encryption-classification-2026-10-28.json').read_text())
        verify = getattr(store_release, 'verify_photographed_configuration', None)
        self.assertTrue(callable(verify), 'Photographed and qualified build settings need an exact bounded comparison')
        verify(candidate, prior, config, evidence)
        for mutation in ['version', 'bundle', 'compiler', 'source', 'encryption', 'proof']:
            with self.subTest(mutation=mutation):
                changed = copy.deepcopy(candidate); proof = copy.deepcopy(evidence)
                if mutation == 'version': changed['settings']['base']['MARKETING_VERSION'] = '0.7.0'
                if mutation == 'bundle': changed['targets']['Hashiya']['settings']['base']['PRODUCT_BUNDLE_IDENTIFIER'] = 'other'
                if mutation == 'compiler': changed['settings']['base']['SWIFT_VERSION'] = '6.0'
                if mutation == 'source': changed['targets']['Hashiya']['sources'].append('DesignStudio')
                if mutation == 'encryption': changed['targets']['Hashiya']['info']['properties']['ITSAppUsesNonExemptEncryption'] = True
                if mutation == 'proof': proof['observed_app_tree'] = 'f' * 40
                with self.assertRaises(ValueError): verify(changed, prior, config, proof)

    def test_authorized_build_can_increase_after_internal_qa_consumes13(self):
        for build in ("13", "14", "15", "9999"):
            with self.subTest(build=build):
                store_release.validate_target({**self.config, "build": build})
        for build in ("12", "0", "013", "14.0", "10000", True, None):
            with self.subTest(build=build), self.assertRaises(ValueError):
                store_release.validate_target({**self.config, "build": build})
    def test_internal_completion_is_separate_from_binary_upload_and_public_review(self):
        import yaml
        workflow = yaml.safe_load(Path('.github/workflows/tayya-store-listing.yml').read_text())
        self.assertIn('complete-internal-qa', list(workflow['jobs']))
        job = workflow['jobs']['complete-internal-qa']
        expression = job['if'].strip().removeprefix('${{').removesuffix('}}').strip()
        for repository, branch, message, expected in [
                ('x6one/hashiya-ios', 'store/tayya-app-store-content', '[store:complete-internal]', True),
                ('x6one/hashiya-ios', 'store/tayya-app-store-content', '[store:publish-approved]', False),
                ('x6one/hashiya-ios', 'integration/tayya-app-store', '[store:complete-internal]', False),
                ('someone/else', 'store/tayya-app-store-content', '[store:complete-internal]', False)]:
            condition = expression.replace('github.repository', repr(repository)).replace('github.ref', repr('refs/heads/' + branch))
            condition = condition.replace('github.event_name', repr('push')).replace('github.event.head_commit.message', repr(message))
            condition = condition.replace('&&', ' and ').replace('||', ' or ')
            self.assertEqual(eval(condition, {'__builtins__': {}}, {'contains': lambda s, t: t in s}), expected)
        self.assertEqual(job['runs-on'], 'ubuntu-latest')
        commands = '\n'.join(s.get('run', '') for s in job['steps'])
        for forbidden in ['python3 Tools/distribute_native_app.py', 'xcodebuild ', 'node Tools/submit_store_review.mjs']:
            self.assertNotIn(forbidden, commands)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.config = dict(app_id="6818288428", bundle_id="com.ahmadalawi.hashiya",
                           version="0.6.0", build="13", app_source="a" * 40,
                           app_tree="b" * 40, qualified_run=42)

    def engine(self, extra=None, source="124ecf55b0f0969b7859d2f803f0bc3a0049a4dc"):
        data = io.BytesIO()
        manifest = {"source": source, "platform": "iphoneos", "architecture": "arm64",
                    "inputs": [{"path": "link-inputs/engine.a", "sha256": hashlib.sha256(b"engine").hexdigest()}]}
        with tarfile.open(fileobj=data, mode="w:gz") as tar:
            for name, content in [("OfficeEngineCandidate/manifest.json", json.dumps(manifest).encode()),
                                  ("OfficeEngineCandidate/link-inputs/engine.a", b"engine")]:
                info = tarfile.TarInfo(name); info.size = len(content)
                tar.addfile(info, io.BytesIO(content))
            if extra:
                tar.addfile(extra, io.BytesIO(b"x" * extra.size))
        archive = self.root / "artifact.zip"
        with zipfile.ZipFile(archive, "w") as zipped:
            zipped.writestr("OfficeEngineCandidate.tar.gz", data.getvalue())
        metadata = {"id": 7, "name": "office-engine-arm64-linking-candidate", "expired": False,
                    "size_in_bytes": archive.stat().st_size,
                    "digest": "sha256:" + hashlib.sha256(archive.read_bytes()).hexdigest(),
                    "workflow_run": {"id": 42, "head_sha": "a" * 40}}
        return archive, metadata

    def test_intact_engine_retains_exact_qualified_run_and_native_source(self):
        archive, meta = self.engine()
        receipt = extract_engine(archive, meta, self.config, self.root / "OfficeEngineCandidate")
        self.assertEqual((self.root / "OfficeEngineCandidate/link-inputs/engine.a").read_bytes(), b"engine")
        self.assertEqual(receipt["qualified_run"], 42)
        self.assertEqual(receipt["application_source"], "a" * 40)
        self.assertEqual(receipt["engine_artifact_id"], 7)
        self.assertFalse(receipt["runtime_tested"])

    def test_another_runs_matching_named_artifact_is_rejected(self):
        archive, meta = self.engine(); meta["workflow_run"]["id"] = 41
        with self.assertRaisesRegex(ValueError, "source|run"):
            extract_engine(archive, meta, self.config, self.root / "OfficeEngineCandidate")
        self.assertFalse((self.root / "OfficeEngineCandidate").exists())

    def test_changed_zip_bytes_fail_before_extraction(self):
        archive, meta = self.engine(); archive.write_bytes(archive.read_bytes() + b"changed")
        with self.assertRaisesRegex(ValueError, "hash|size|digest"):
            extract_engine(archive, meta, self.config, self.root / "OfficeEngineCandidate")
        self.assertFalse((self.root / "OfficeEngineCandidate").exists())

    def test_unsafe_tar_entries_do_not_escape_or_create_output(self):
        for name, kind in [("OfficeEngineCandidate/../../escaped", tarfile.REGTYPE),
                           ("OfficeEngineCandidate/link", tarfile.SYMTYPE),
                           ("OfficeEngineCandidate/link", tarfile.LNKTYPE)]:
            with self.subTest(name=name, kind=kind):
                info = tarfile.TarInfo(name); info.type = kind; info.linkname = "../../escaped"
                archive, meta = self.engine(info)
                with self.assertRaisesRegex(ValueError, "Unsafe|unsafe"):
                    extract_engine(archive, meta, self.config, self.root / "OfficeEngineCandidate")
                self.assertFalse((self.root / "OfficeEngineCandidate").exists())
                self.assertFalse((self.root / "escaped").exists())

    def test_engine_from_other_upstream_cannot_be_published(self):
        archive, meta = self.engine(source="f" * 40)
        with self.assertRaisesRegex(ValueError, "engine|upstream"):
            extract_engine(archive, meta, self.config, self.root / "OfficeEngineCandidate")

    def listing(self):
        return dict(app_id="6818288428", version="0.6.0", build="13", application_tree="b" * 40,
                    result="new-version-metadata-and-branded-images-ready", submitted_for_review=False,
                    screenshots=[dict(id=f"{locale}/{family}/{n}", locale=locale, family=family,
                                      state="COMPLETE", file=f"{n:02d}.png")
                                 for locale in ["ar-SA", "en-US"] for family in ["iPhone", "iPad"]
                                 for n in range(1, 7)])

    def test_only_the_complete_24_photo_draft_qualifies(self):
        report = self.listing(); verify_listing(report, self.config)
        for mutation in ["processing", "missing", "duplicate", "wrong_version"]:
            with self.subTest(mutation=mutation):
                report = self.listing()
                if mutation == "processing": report["screenshots"][0]["state"] = "PROCESSING"
                if mutation == "missing": report["screenshots"].pop()
                if mutation == "duplicate": report["screenshots"][0] = report["screenshots"][1]
                if mutation == "wrong_version": report["version"] = "0.4.2"
                with self.assertRaises(ValueError): verify_listing(report, self.config)

    def test_publication_requires_explicit_target_branch_flag_and_request(self):
        config = {**self.config, "publish_binary": True}
        environment = dict(GITHUB_EVENT_NAME="push", GITHUB_REPOSITORY="x6one/hashiya-ios",
                           GITHUB_REF="refs/heads/store/tayya-app-store-content")
        event = {"head_commit": {"message": "Publish approved0.6.0(13) [store:publish-approved]"}}
        verify_authorization(config, environment, event)
        for mutation in ["flag", "branch", "repository", "event", "tag", "target"]:
            with self.subTest(mutation=mutation):
                c = dict(config); env = dict(environment); request = json.loads(json.dumps(event))
                if mutation == "flag": c["publish_binary"] = False
                if mutation == "branch": env["GITHUB_REF"] = "refs/heads/main"
                if mutation == "repository": env["GITHUB_REPOSITORY"] = "other/hashiya-ios"
                if mutation == "event": env["GITHUB_EVENT_NAME"] = "pull_request"
                if mutation == "tag": request["head_commit"]["message"] = "Documentation only"
                if mutation == "target": c["build"] = "12"
                with self.assertRaises(ValueError): verify_authorization(c, env, request)

    def distribution(self):
        repo = self.root / "qualified"; repo.mkdir()
        git = lambda *a: subprocess.check_output(["git", "-C", str(repo), *a], text=True).strip()
        git("init", "--quiet"); git("config", "user.name", "Fixture"); git("config", "user.email", "fixture@example.invalid")
        (repo / "App").mkdir(); (repo / "App/code.swift").write_text("// actual qualified app\n")
        git("add", "."); git("commit", "--quiet", "-m", "qualified fixture")
        self.config.update(app_source=git("rev-parse", "HEAD"), app_tree=git("rev-parse", "HEAD:App"))
        output = self.root / "AppleDistribution"; (output / "Export").mkdir(parents=True)
        ipa = output / "Export/Tayya.ipa"
        with zipfile.ZipFile(ipa, "w") as zipped: zipped.writestr("Payload/Hashiya.app/Hashiya", b"signed fixture")
        report = dict(source_commit="c" * 40, bundle_id="com.ahmadalawi.hashiya", team="ZUB6SJFQA3",
                      version="0.6.0", build="13", code_signed=True, archive_only=False,
                      upload_accepted=True, apple_processing_confirmed=False, app_store_submitted=False,
                      sha256=hashlib.sha256(ipa.read_bytes()).hexdigest())
        (output / "distribution-report.json").write_text(json.dumps(report))
        return repo, output, ipa

    def test_provenance_distinguishes_controller_from_actual_checkout(self):
        repo, output, _ = self.distribution()
        receipt = write_provenance(self.config, repo, output, {"qualified_run": 42}, "c" * 40)
        self.assertEqual(receipt["application_source"], self.config["app_source"])
        self.assertEqual(receipt["controller_source"], "c" * 40)
        self.assertNotEqual(receipt["application_source"], receipt["controller_source"])
        self.assertFalse(receipt["apple_processing_confirmed"])
        self.assertFalse(receipt["app_store_submitted"])

    def test_provenance_rejects_dirty_or_wrong_source_and_changed_ipa(self):
        repo, output, ipa = self.distribution()
        args = (self.config, repo, output, {"qualified_run": 42}, "c" * 40)
        (repo / "App/code.swift").write_text("// different app")
        with self.assertRaisesRegex(ValueError, "modified|dirty"): write_provenance(*args)
        subprocess.run(["git", "-C", str(repo), "restore", "App/code.swift"], check=True)
        self.config["app_source"] = "d" * 40
        with self.assertRaisesRegex(ValueError, "source|checkout"): write_provenance(*args)
        self.config["app_source"] = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()
        ipa.write_bytes(ipa.read_bytes() + b"modified")
        with self.assertRaisesRegex(ValueError, "hash|digest"): write_provenance(*args)


class AppleProcessingTests(unittest.TestCase):
    def test_processing_requires_the_exact_configured_build_not_old_qa13(self):
        self.config["build"] = "14"
        self.apple.update(target_build="14", builds=[dict(id="official-14", build="14", version="0.6.0", processing="VALID")],
                          version_0_6_build_exists=True)
        self.assertEqual(self.inspect()["apple_build_id"], "official-14")
        self.apple["target_build"] = "13"
        with self.assertRaisesRegex(ValueError, "identity|target|build"):
            self.inspect()

    def setUp(self):
        self.config = dict(app_id="6818288428", bundle_id="com.ahmadalawi.hashiya", version="0.6.0", build="13",
                           app_source="a" * 40, app_tree="b" * 40, qualified_run=42)
        self.upload = dict(application_source="a" * 40, application_tree="b" * 40, controller_source="c" * 40,
                           qualified_run=42, signed_ipa_sha256="d" * 64, upload_accepted=True,
                           apple_processing_confirmed=False, app_store_submitted=False,
                           engine=dict(application_source="a" * 40, qualified_run=42))
        self.apple = dict(read_only=True, ready_for_distribution_authentication=True,
                          app=dict(id="6818288428", bundle_id="com.ahmadalawi.hashiya"),
                          target_build="13", builds=[], version_0_6_build_exists=False)

    def inspect(self):
        validator = getattr(store_release, "verify_processing", None)
        self.assertTrue(callable(validator), "Missing pure post-upload Apple processing validator")
        return validator(self.config, self.apple, self.upload, "c" * 40)

    def build(self, status, version="0.6.0"):
        self.apple["builds"] = [dict(id="build-13", build="13", version=version, processing=status)]
        self.apple["version_0_6_build_exists"] = version == "0.6.0"

    def test_missing_or_another_version_is_pending_not_an_upload_retry(self):
        self.assertFalse(self.inspect()["apple_processing_confirmed"])
        self.build("VALID", version="0.4.2")
        result = self.inspect()
        self.assertFalse(result["apple_processing_confirmed"])
        self.assertEqual(result["processing_state"], "NOT_LISTED_YET")
        self.assertTrue(result["upload_accepted"])

    def test_processing_is_not_a_processed_or_submitted_app(self):
        self.build("PROCESSING")
        result = self.inspect()
        self.assertFalse(result["apple_processing_confirmed"])
        self.assertFalse(result["app_store_submitted"])
        self.assertEqual(result["apple_build_id"], "build-13")

    def test_only_exact_valid_build_retains_the_attested_app_and_ipa(self):
        self.build("VALID")
        result = self.inspect()
        self.assertTrue(result["apple_processing_confirmed"])
        self.assertFalse(result["app_store_submitted"])
        self.assertTrue(result["read_only"])
        self.assertEqual(result["application_source"], "a" * 40)
        self.assertEqual(result["signed_ipa_sha256"], "d" * 64)
        self.assertFalse(self.upload["apple_processing_confirmed"], "Original signer receipt stays immutable")

    def test_failed_invalid_and_unknown_states_do_not_pass_or_wait_forever(self):
        for status in ("FAILED", "INVALID", "UNKNOWN"):
            with self.subTest(status=status):
                self.build(status)
                with self.assertRaisesRegex(ValueError, "processing"):
                    self.inspect()

    def test_duplicate_and_inconsistent_identity_are_rejected(self):
        self.build("VALID")
        self.apple["builds"].append(dict(self.apple["builds"][0], id="other"))
        with self.assertRaisesRegex(ValueError, "identity|Ambiguous"):
            self.inspect()
        self.build("VALID"); self.apple["version_0_6_build_exists"] = False
        with self.assertRaisesRegex(ValueError, "identity|Inconsistent"):
            self.inspect()

    def test_wrong_app_or_unverified_api_state_is_rejected(self):
        for key in ("id", "bundle_id"):
            original = self.apple["app"][key]; self.apple["app"][key] = "other"
            with self.assertRaisesRegex(ValueError, "Apple|app"):
                self.inspect()
            self.apple["app"][key] = original
        self.apple["read_only"] = False
        with self.assertRaisesRegex(ValueError, "Apple|read"):
            self.inspect()

    def test_unaccepted_or_other_source_controller_and_ipa_receipt_are_rejected(self):
        for key, wrong in [("application_source", "e" * 40), ("application_tree", "e" * 40),
                           ("controller_source", "e" * 40), ("qualified_run", 43),
                           ("upload_accepted", False), ("signed_ipa_sha256", "bad"),
                           ("app_store_submitted", True)]:
            original = self.upload[key]; self.upload[key] = wrong
            with self.subTest(field=key), self.assertRaisesRegex(ValueError, "attested|receipt|upload"):
                self.inspect()
            self.upload[key] = original

    def test_engine_receipt_cannot_be_taken_from_another_qualification(self):
        self.upload["engine"]["qualified_run"] = 43
        with self.assertRaisesRegex(ValueError, "attested|receipt|upload"):
            self.inspect()

    def test_cli_terminal_failure_replaces_a_previously_valid_report(self):
        script = Path(store_release.__file__).resolve()
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for name in ("Store", "StoreDraft", "AppleDistribution"):
                (root / name).mkdir()
            def write(name, value):
                (root / name).write_text(json.dumps(value))
            write("Store/publication.json", {**self.config, "publish_binary": True})
            write("event.json", {"head_commit": {"message": "[store:publish-approved]"}})
            write("StoreDraft/store-listing-report.json", StoreReleaseTests.listing(self))
            write("AppleDistribution/store-publication-provenance.json", self.upload)
            environment = {**os.environ, "GITHUB_EVENT_NAME": "push", "GITHUB_REPOSITORY": "x6one/hashiya-ios",
                           "GITHUB_REF": "refs/heads/store/tayya-app-store-content", "GITHUB_SHA": "c" * 40,
                           "GITHUB_EVENT_PATH": str(root / "event.json")}
            self.build("VALID")
            write("store-after-upload.json", self.apple)
            result = subprocess.run(["python3", str(script), "processing"], cwd=root, env=environment,
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.build("FAILED")
            write("store-after-upload.json", self.apple)
            result = subprocess.run(["python3", str(script), "processing"], cwd=root, env=environment,
                                    capture_output=True, text=True)
            self.assertNotIn(result.returncode, (0, 10), result.stderr)
            report = json.loads((root / "store-processing-report.json").read_text())
            self.assertFalse(report["apple_processing_confirmed"], "A prior VALID response must not survive failure")
            self.assertFalse(report["app_store_submitted"])
            self.assertEqual(report["processing_state"], "VERIFICATION_FAILED")
            self.assertIn("failed", report["error"])


class QualifiedBinaryBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.config = dict(app_id="6818288428", bundle_id="com.ahmadalawi.hashiya", version="0.6.0", build="15",
                           app_source="a" * 40, app_tree="b" * 40, qualified_run=42, artwork_source="d" * 40,
                           publish_binary=True, upload_qualified_binary=True,
                           store_listing_blocker=dict(run=43, controller="c" * 40))
        self.environment = dict(GITHUB_EVENT_NAME="push", GITHUB_REPOSITORY="x6one/hashiya-ios",
                                GITHUB_REF="refs/heads/store/tayya-app-store-content")
        self.event = dict(head_commit=dict(message="[store:upload-qualified-binary]"))
        self.blocked = dict(app_id="6818288428", version="0.6.0", build="15", application_tree="b" * 40,
                            artwork_source="d" * 40, run="43", mode="prepare-draft-only", screenshots=[], screenshot_sets=[],
                            error="Apple API POST appStoreVersions HTTP 403: FORBIDDEN_ERROR")

    def verify(self, config=None, environment=None, event=None, listing=None):
        check = getattr(store_release, "verify_binary_listing_authorization", None)
        self.assertTrue(callable(check), "A metadata403 cannot silently satisfy the public Store gate; explicit upload-only authorization is required")
        return check(config or self.config, environment or self.environment, event or self.event, listing or self.blocked)

    def test_explicit_qualified_binary_upload_does_not_attest_store_readiness(self):
        self.assertEqual(self.verify(), dict(upload_only=True, store_listing_ready=False, app_review_submitted=False))
        with self.assertRaises(ValueError):
            verify_listing(self.blocked, self.config)
        with self.assertRaises(ValueError):
            verify_authorization(self.config, self.environment, self.event)

    def test_wrong_scope_or_other_failure_cannot_enable_binary_only_upload(self):
        for key,value in [("publish_binary",False),("upload_qualified_binary",False),("app_id","another"),("build","14")]:
            with self.subTest(config=key):
                changed=copy.deepcopy(self.config);changed[key]=value
                with self.assertRaises(ValueError):self.verify(config=changed)
        for key,value in [("GITHUB_EVENT_NAME","pull_request"),("GITHUB_REPOSITORY","other/repo"),("GITHUB_REF","refs/heads/main")]:
            with self.subTest(scope=key):
                changed=dict(self.environment);changed[key]=value
                with self.assertRaises(ValueError):self.verify(environment=changed)
        with self.assertRaises(ValueError):self.verify(event=dict(head_commit=dict(message="[store:publish-approved]")))
        for key,value in [("error","Apple API POST appStoreVersions HTTP 500: SERVER_ERROR"),("run","44"),
                          ("application_tree","e"*40),("version","0.4.2"),("screenshots",[{"state":"FAILED"}])]:
            with self.subTest(proof=key):
                changed=copy.deepcopy(self.blocked);changed[key]=value
                with self.assertRaises(ValueError):self.verify(listing=changed)


class SignedArtifactRetentionTests(unittest.TestCase):
    def exercise_retention(self, fail_archive):
        from contextlib import chdir
        from unittest.mock import patch
        import plistlib
        import sys
        import yaml
        repository = Path.cwd()
        workflow = yaml.safe_load(Path('.github/workflows/tayya-store-listing.yml').read_text())
        step = next(s for s in workflow['jobs']['qualified-binary']['steps'] if s.get('name','').startswith('Retain the verified signed IPA'))
        script = step['run'].split("python3 - <<'PY_VERIFIED'\n", 1)[1].split('\nPY_VERIFIED', 1)[0]
        actual_run = subprocess.run
        with tempfile.TemporaryDirectory() as folder, chdir(folder):
            root = Path(folder)
            app_source = root / 'hashiya-tools'
            (app_source / 'App').mkdir(parents=True)
            (app_source / 'App/main.swift').write_text('// isolated source fixture')
            for command in [['git','init','-q',str(app_source)], ['git','-C',str(app_source),'add','.'],
                            ['git','-C',str(app_source),'-c','user.name=Test','-c','user.email=test@example.invalid','commit','-qm','fixture']]:
                actual_run(command,check=True)
            git = lambda value: subprocess.check_output(['git','-C',str(app_source),'rev-parse',value],text=True).strip()
            config = dict(app_id='6818288428',bundle_id='com.ahmadalawi.hashiya',version='0.6.0',build='15',
                          app_source=git('HEAD'),app_tree=git('HEAD:App'),qualified_run=42,store_listing_blocker=dict(http_status=403))
            Path('Store').mkdir();Path('Store/publication.json').write_text(json.dumps(config))
            distribution = Path('AppleDistribution');(distribution/'Export').mkdir(parents=True)
            archive_app=distribution/'Tayya.xcarchive/Products/Applications/Hashiya.app';archive_app.mkdir(parents=True)
            (archive_app/'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier='com.ahmadalawi.hashiya',CFBundleShortVersionString='0.6.0',CFBundleVersion='15',CFBundleExecutable='Hashiya')))
            (archive_app/'Hashiya').write_bytes(b'platform-signature-boundary-fixture')
            ipa=distribution/'Export/fixture.ipa'
            with zipfile.ZipFile(ipa,'w') as packed:packed.writestr('Payload/Hashiya.app/fixture',b'isolated IPA bytes')
            report=dict(source_commit='c'*40,team='ZUB6SJFQA3',code_signed=True,archive_retained=True,upload_accepted=False,
                        sha256=hashlib.sha256(ipa.read_bytes()).hexdigest())
            (distribution/'distribution-report.json').write_text(json.dumps(report))
            Path('store-engine-receipt.json').write_text(json.dumps(dict(application_source=config['app_source'],qualified_run=42)))
            def platform(command, *args, **kwargs):
                if command[0] in ['codesign','xcrun']:
                    # Native signature verification belongs to macOS CI. Keep
                    # real filesystem/ZIP/digest/source logic under test here.
                    return subprocess.CompletedProcess(command,0)
                if command[0]=='ditto':
                    target=Path(command[-1])
                    if fail_archive:
                        target.write_bytes(b'interrupted partial archive')
                        raise subprocess.CalledProcessError(1,command)
                    with zipfile.ZipFile(target,'w') as packed:
                        packed.writestr('Tayya.xcarchive/Products/Applications/Hashiya.app/Info.plist',(archive_app/'Info.plist').read_bytes())
                    return subprocess.CompletedProcess(command,0)
                return actual_run(command,*args,**kwargs)
            with patch.dict(os.environ,{'GITHUB_SHA':'c'*40}), patch.object(sys,'path',[str(repository),*sys.path]), patch('subprocess.run',side_effect=platform):
                if fail_archive:
                    with self.assertRaises(subprocess.CalledProcessError):exec(compile(script,'actual-retention-workflow','exec'),{})
                else:exec(compile(script,'actual-retention-workflow','exec'),{})
            if fail_archive:
                self.assertFalse((distribution/'Verified').exists(),'An always-uploaded path must not expose any partial IPA/archive after packaging fails')
            else:
                self.assertTrue((distribution/'Verified/SHA256SUMS').is_file())
                proof=json.loads((distribution/'Verified/release-provenance.json').read_text())
                self.assertFalse(proof['upload_accepted'])
                self.assertFalse(proof['store_listing_ready'])
                self.assertEqual(hashlib.sha256((distribution/'Verified/Tayya.ipa').read_bytes()).hexdigest(),report['sha256'])

    def test_interrupted_packaging_never_exposes_partial_signed_artifacts(self):
        self.exercise_retention(True)

    def test_complete_packaging_exposes_a_digest_verified_pair_without_claiming_upload(self):
        self.exercise_retention(False)



if __name__ == "__main__": unittest.main()
