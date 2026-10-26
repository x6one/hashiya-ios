"""Exercise the real release-artifact and source-attribution boundaries."""
import hashlib
import io
import json
import subprocess
import tarfile
import tempfile
import unittest
import zipfile
from pathlib import Path

from store_release import extract_engine, verify_listing, write_provenance, verify_authorization


class StoreReleaseTests(unittest.TestCase):
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
                if mutation == "target": c["build"] = "14"
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


if __name__ == "__main__": unittest.main()
