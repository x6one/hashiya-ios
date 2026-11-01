"""Consume a qualified Office artifact and attest the separately checked-out app.

No signing credentials, Apple API calls or changes to the original build/signing
helpers belong here. Only the explicitly authorized Store controller may run it.
"""
import argparse
import copy
import hashlib
import json
import os
import re
import shutil
import subprocess
import tarfile
import tempfile
import zipfile
from pathlib import Path, PurePosixPath

ENGINE = "124ecf55b0f0969b7859d2f803f0bc3a0049a4dc"
ARTIFACT = "office-engine-arm64-linking-candidate"
MAX_ARCHIVE = 2 * 1024**3


def digest(path):
    with path.open("rb") as file:
        return hashlib.file_digest(file, "sha256").hexdigest()


def validate_target(config):
    build = str(config.get("build"))
    if ((config.get("app_id"), config.get("bundle_id"), config.get("version")) != (
            "6818288428", "com.ahmadalawi.hashiya", "0.6.0")
            or not re.fullmatch(r"[1-9]\d{1,3}", build) or int(build) < 13):
        raise ValueError("Only the authorized Tayya0.6.0 target with an integer build13 or higher is allowed")
    for key in ("app_source", "app_tree"):
        if not re.fullmatch("[a-f0-9]{40}", config.get(key, "")):
            raise ValueError("Invalid application source pin")
    if not str(config.get("qualified_run", "")).isdigit():
        raise ValueError("Invalid qualified run")


def verify_photographed_configuration(candidate, artwork, config, encryption_evidence):
    """Allow only nonvisual, explicitly verified release metadata differences."""
    validate_target(config)
    normalized = copy.deepcopy(candidate)
    settings = normalized["settings"]["base"]
    if (str(settings["CURRENT_PROJECT_VERSION"]) != str(config["build"])
            or str(settings["MARKETING_VERSION"]) != config["version"]):
        raise ValueError("Candidate version/build differs from the qualified target")
    settings["CURRENT_PROJECT_VERSION"] = artwork["settings"]["base"]["CURRENT_PROJECT_VERSION"]
    info = normalized["targets"]["Hashiya"]["info"]["properties"]
    old_info = artwork["targets"]["Hashiya"]["info"]["properties"]
    key = "ITSAppUsesNonExemptEncryption"
    if key in info and key not in old_info:
        proof = encryption_evidence
        if (info[key] is not False or proof.get("uses_non_exempt_encryption") is not False
                or proof.get("app_id") != config["app_id"] or proof.get("bundle_id") != config["bundle_id"]
                or proof.get("observed_app_tree") != config["app_tree"]
                or proof.get("previous_published_version") != "0.4.2"
                or proof.get("previous_published_build_id") != "1bce9a90-1e02-4523-b19b-b06a6afc28d4"
                or proof.get("excluded_territories") != ["FRA"]
                or proof.get("evidence_artifact") != 12833207997
                or proof.get("evidence_artifact_sha256") != "a35c10ed57aeed378a1743a37480c38df5cab88cbd5a5ca1169f7fd1ac0b4242"):
            raise ValueError("Changed encryption declaration lacks exact audited Apple evidence")
        del info[key]
    if normalized != artwork:
        raise ValueError("Photographed build configuration differs beyond audited nonvisual metadata")


def verify_authorization(config, environment, event):
    validate_target(config)
    if (config.get("publish_binary") is not True or environment.get("GITHUB_EVENT_NAME") != "push"
            or environment.get("GITHUB_REPOSITORY") != "x6one/hashiya-ios"
            or environment.get("GITHUB_REF") != "refs/heads/store/tayya-app-store-content"
            or "[store:publish-approved]" not in event.get("head_commit", {}).get("message", "")):
        raise ValueError("Explicit authorized Store publication request is absent")


def verify_binary_scope(config, environment, event):
    validate_target(config)
    if (config.get("publish_binary") is not True or config.get("upload_qualified_binary") is not True
            or environment.get("GITHUB_EVENT_NAME") != "push"
            or environment.get("GITHUB_REPOSITORY") != "x6one/hashiya-ios"
            or environment.get("GITHUB_REF") != "refs/heads/store/tayya-app-store-content"
            or "[store:upload-qualified-binary]" not in event.get("head_commit", {}).get("message", "")):
        raise ValueError("Explicit qualified binary-only upload authorization is absent")


def verify_binary_listing_authorization(config, environment, event, listing):
    """A proved Store403 permits an authorized binary upload, never App Review."""
    verify_binary_scope(config, environment, event)
    blocker = config.get("store_listing_blocker", {})
    if (not str(blocker.get("run", "")).isdigit()
            or not re.fullmatch("[a-f0-9]{40}", blocker.get("controller", ""))
            or any(str(listing.get(key)) != str(config[key]) for key in ("app_id", "version", "build"))
            or listing.get("application_tree") != config["app_tree"]
            or listing.get("artwork_source") != config["artwork_source"]
            or listing.get("run") != str(blocker["run"])
            or listing.get("mode") != "prepare-draft-only"
            or listing.get("error") != "Apple API POST appStoreVersions HTTP 403: FORBIDDEN_ERROR"
            or listing.get("screenshots") != [] or listing.get("screenshot_sets") != []):
        raise ValueError("Binary-only upload requires this exact preserved Apple metadata403")
    return {"upload_only": True, "store_listing_ready": False, "app_review_submitted": False}


def fetch_binary_listing_proof(config, environment, event):
    verify_binary_scope(config, environment, event)
    blocker = config.get("store_listing_blocker", {})
    if (not str(blocker.get("artifact", "")).isdigit()
            or not re.fullmatch("[a-f0-9]{64}", blocker.get("sha256", ""))
            or not isinstance(blocker.get("bytes"), int) or not 0 < blocker["bytes"] < 65536):
        raise ValueError("Invalid preserved Store403 artifact identity")
    endpoint = f"repos/x6one/hashiya-ios/actions/artifacts/{blocker['artifact']}"
    metadata = json.loads(subprocess.check_output(["gh", "api", endpoint], text=True))
    if (metadata.get("expired") is not False or metadata.get("name") != "Tayya-Store-draft-receipt"
            or metadata.get("workflow_run", {}).get("id") != blocker.get("run")
            or metadata.get("workflow_run", {}).get("head_sha") != blocker.get("controller")
            or metadata.get("size_in_bytes") != blocker["bytes"]
            or metadata.get("digest") != "sha256:" + blocker["sha256"]):
        raise ValueError("Preserved Store403 artifact source/run/digest differs")
    archive = Path("preserved-store403.zip")
    with archive.open("xb") as output:
        subprocess.run(["gh", "api", endpoint + "/zip"], stdout=output, check=True)
    if archive.stat().st_size != blocker["bytes"] or digest(archive) != blocker["sha256"]:
        raise ValueError("Preserved Store403 ZIP bytes differ")
    with zipfile.ZipFile(archive) as zipped:
        if (sorted(zipped.namelist()) != ["store-apple-readiness.json", "store-listing-report.json"]
                or sum(row.file_size for row in zipped.infolist()) > 65536 or zipped.testzip() is not None):
            raise ValueError("Invalid preserved Store403 ZIP structure")
        listing = json.loads(zipped.read("store-listing-report.json"))
        readiness = json.loads(zipped.read("store-apple-readiness.json"))
        verify_binary_listing_authorization(config, environment, event, listing)
        if (readiness.get("source") != blocker["controller"] or readiness.get("read_only") is not True
                or readiness.get("app", {}).get("id") != config["app_id"]
                or readiness.get("app", {}).get("bundle_id") != config["bundle_id"]):
            raise ValueError("Store403 read-only Apple identity is not verified")
        root = Path("StoreDraft")
        root.mkdir(exist_ok=False)
        for name in zipped.namelist():
            (root / name).write_bytes(zipped.read(name))


def verify_listing(report, config):
    validate_target(config)
    if any(str(report.get(key)) != str(config[key]) for key in ("app_id", "version", "build")):
        raise ValueError("The draft belongs to another target")
    if (report.get("application_tree") != config["app_tree"]
            or report.get("result") != "new-version-metadata-and-branded-images-ready"
            or report.get("submitted_for_review") is not False):
        raise ValueError("The approved draft is incomplete or has changed")
    photos = report.get("screenshots", [])
    if len(photos) != 24 or len({p.get("id") for p in photos}) != 24:
        raise ValueError("Expected24 distinct processed screenshot resources")
    for locale in ("ar-SA", "en-US"):
        for family in ("iPhone", "iPad"):
            group = [p for p in photos if p.get("locale") == locale and p.get("family") == family]
            if len(group) != 6 or any(p.get("state") != "COMPLETE" for p in group) or len({p.get("file") for p in group}) != 6:
                raise ValueError("Each locale/device requires six COMPLETE approved images")


def extract_engine(archive, metadata, config, output):
    validate_target(config)
    origin = metadata.get("workflow_run", {})
    if (origin.get("id") != config["qualified_run"] or origin.get("head_sha") != config["app_source"]):
        raise ValueError("Engine artifact source/run differs from the qualified app")
    if metadata.get("name") != ARTIFACT or metadata.get("expired") is not False:
        raise ValueError("Wrong or expired engine artifact")
    expected = metadata.get("digest", "")
    if (not re.fullmatch("sha256:[a-f0-9]{64}", expected)
            or not 0 < archive.stat().st_size < MAX_ARCHIVE
            or archive.stat().st_size != metadata.get("size_in_bytes")
            or "sha256:" + digest(archive) != expected):
        raise ValueError("Engine artifact size/digest mismatch")
    output = output.resolve()
    if output.exists() or output.name != "OfficeEngineCandidate":
        raise ValueError("Use a new OfficeEngineCandidate output")
    with tempfile.TemporaryDirectory(prefix="tayya-engine-", dir=output.parent) as folder:
        staging = Path(folder)
        packed = staging / "engine.tar.gz"
        with zipfile.ZipFile(archive) as zipped:
            entries = zipped.infolist()
            if (len(entries) != 1 or entries[0].filename != "OfficeEngineCandidate.tar.gz"
                    or not 0 < entries[0].file_size < MAX_ARCHIVE):
                raise ValueError("Unexpected engine ZIP contents")
            with zipped.open(entries[0]) as source, packed.open("wb") as target:
                shutil.copyfileobj(source, target)  # Reading to EOF verifies ZIP CRC.
        with tarfile.open(packed, "r:gz") as tar:
            members = tar.getmembers()
            names = set()
            if len(members) > 100000 or sum(m.size for m in members) > 16 * 1024**3:
                raise ValueError("Engine package exceeds extraction bounds")
            for member in members:
                path = PurePosixPath(member.name)
                if (path.is_absolute() or ".." in path.parts or "\\" in member.name
                        or not path.parts or path.parts[0] != "OfficeEngineCandidate"
                        or not (member.isfile() or member.isdir()) or path.as_posix() in names):
                    raise ValueError("Unsafe or duplicate engine tar entry")
                names.add(path.as_posix())
            try:
                manifest = json.load(tar.extractfile("OfficeEngineCandidate/manifest.json"))
            except (KeyError, TypeError, ValueError) as error:
                raise ValueError("Missing valid engine manifest") from error
            if (manifest.get("source") != ENGINE or manifest.get("platform") != "iphoneos"
                    or manifest.get("architecture") != "arm64" or not manifest.get("inputs")):
                raise ValueError("Wrong upstream engine source, platform or architecture")
            inputs = set()
            for row in manifest["inputs"]:
                path = PurePosixPath(row["path"])
                if (path.is_absolute() or ".." in path.parts or "\\" in row["path"]
                        or not path.parts or path.parts[0] != "link-inputs"
                        or path.as_posix() in inputs or "OfficeEngineCandidate/" + path.as_posix() not in names
                        or not re.fullmatch("[a-f0-9]{64}", row["sha256"])):
                    raise ValueError("Unsafe engine link input")
                inputs.add(path.as_posix())
            for member in members:
                target = staging / member.name
                if member.isdir():
                    target.mkdir(parents=True, exist_ok=True)
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with tar.extractfile(member) as source, target.open("xb") as destination:
                        shutil.copyfileobj(source, destination)
                    target.chmod(member.mode & 0o755)
        # Original link_office_engine.py rehashes every input before native linkage.
        (staging / "OfficeEngineCandidate").rename(output)
    return {"application_source": config["app_source"], "qualified_run": config["qualified_run"],
            "engine_artifact_id": metadata["id"], "engine_artifact_sha256": expected[7:],
            "engine_source": ENGINE, "platform": "iphoneos", "architecture": "arm64", "runtime_tested": False}


def verify_checkout(config, repository):
    validate_target(config)
    git = lambda *args: subprocess.check_output(["git", "-C", str(repository), *args], text=True).strip()
    if git("rev-parse", "HEAD") != config["app_source"] or git("rev-parse", "HEAD:App") != config["app_tree"]:
        raise ValueError("Actual checkout source differs from the qualified app")
    if git("diff", "--name-only", "HEAD") or git("ls-files", "--others", "--exclude-standard", "App", "NativeOffice"):
        raise ValueError("Qualified app checkout was modified or dirty")


def write_provenance(config, repository, distribution, engine_receipt, controller):
    verify_checkout(config, repository)
    raw_path = distribution / "distribution-report.json"
    raw = json.loads(raw_path.read_text())
    if (raw.get("source_commit") != controller or raw.get("team") != "ZUB6SJFQA3"
            or any(str(raw.get(key)) != str(config[key]) for key in ("bundle_id", "version", "build"))
            or raw.get("code_signed") is not True or raw.get("upload_accepted") is not True
            or raw.get("archive_only") is not False or raw.get("apple_processing_confirmed") is not False
            or raw.get("app_store_submitted") is not False or engine_receipt["qualified_run"] != config["qualified_run"]):
        raise ValueError("The original signer did not attest this authorized upload")
    ipas = list((distribution / "Export").glob("*.ipa"))
    if len(ipas) != 1 or digest(ipas[0]) != raw.get("sha256"):
        raise ValueError("Signed IPA digest does not match the unmodified signer receipt")
    return {"application_source": config["app_source"], "application_tree": config["app_tree"],
            "controller_source": controller, "qualified_run": config["qualified_run"],
            "engine": engine_receipt, "signer_receipt_sha256": digest(raw_path),
            "signed_ipa_sha256": raw["sha256"], "upload_accepted": True,
            "apple_processing_confirmed": False, "app_store_submitted": False,
            "legacy_source_commit_meaning": "Original signer records the controller GITHUB_SHA; actual built checkout is application_source."}


def verify_upload_receipt(config, upload, controller):
    validate_target(config)
    engine = upload.get("engine", {})
    if (upload.get("application_source") != config["app_source"]
            or upload.get("application_tree") != config["app_tree"]
            or upload.get("controller_source") != controller
            or upload.get("qualified_run") != config["qualified_run"]
            or engine.get("qualified_run") != config["qualified_run"]
            or engine.get("application_source") != config["app_source"]
            or upload.get("upload_accepted") is not True
            or upload.get("app_store_submitted") is not False
            or upload.get("apple_processing_confirmed") is not False
            or not re.fullmatch(r"[a-f0-9]{64}", upload.get("signed_ipa_sha256", ""))):
        raise ValueError("Processing requires the attested immutable upload receipt")


def verify_processing(config, apple, upload, controller):
    """Classify a read-only Apple response; never infer review or repeat upload."""
    verify_upload_receipt(config, upload, controller)
    if (apple.get("read_only") is not True
            or apple.get("ready_for_distribution_authentication") is not True
            or apple.get("app", {}).get("id") != config["app_id"]
            or apple.get("app", {}).get("bundle_id") != config["bundle_id"]):
        raise ValueError("Unverified read-only Apple app response")
    if apple.get("target_build") != str(config["build"]):
        raise ValueError("Apple response belongs to a different target build")
    matches = [b for b in apple.get("builds", [])
               if b.get("build") == str(config["build"]) and b.get("version") == config["version"]]
    if len(matches) > 1:
        raise ValueError("Ambiguous Apple build identity")
    if apple.get("version_0_6_build_exists") is not bool(matches):
        raise ValueError("Inconsistent Apple build identity")
    build = matches[0] if matches else None
    status = build.get("processing") if build else "NOT_LISTED_YET"
    if status not in ("NOT_LISTED_YET", "PROCESSING", "VALID"):
        raise ValueError("Apple processing is failed, invalid or unrecognized: " + str(status))
    if build and (not isinstance(build.get("id"), str) or not re.fullmatch(r"[a-zA-Z0-9-]+", build["id"])):
        raise ValueError("Invalid Apple build identity")
    return {"application_source": config["app_source"], "application_tree": config["app_tree"],
            "controller_source": controller, "qualified_run": config["qualified_run"],
            "version": config["version"], "build": str(config["build"]),
            "apple_build_id": build["id"] if build else None, "processing_state": status,
            "signed_ipa_sha256": upload["signed_ipa_sha256"], "upload_accepted": True,
            "apple_processing_confirmed": status == "VALID", "app_store_submitted": False,
            "read_only": True, "scope": "Apple build processing only; export compliance, attachment and review are separate."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=["engine", "source", "receipt", "processing", "processing-source", "binary-proof", "binary-engine", "binary-source", "binary-receipt", "binary-processing", "binary-processing-source"])
    args = parser.parse_args()
    config = json.loads(Path("Store/publication.json").read_text())
    event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
    binary = args.operation.startswith("binary-")
    operation = args.operation.removeprefix("binary-")
    if binary:
        if operation == "proof":
            fetch_binary_listing_proof(config, os.environ, event)
            print("Exact preserved Apple403 verified; this authorizes no metadata writes or review submission")
            return
        boundary = verify_binary_listing_authorization(config, os.environ, event,
            json.loads(Path("StoreDraft/store-listing-report.json").read_text()))
    else:
        verify_authorization(config, os.environ, event)
        verify_listing(json.loads(Path("StoreDraft/store-listing-report.json").read_text()), config)
    if operation in ("processing", "processing-source"):
        upload = json.loads(Path("AppleDistribution/store-publication-provenance.json").read_text())
        verify_upload_receipt(config, upload, os.environ["GITHUB_SHA"])
        if operation == "processing-source":
            print("Current trusted upload receipt is qualified; no Apple credential has been used")
            return
        try:
            receipt = verify_processing(config, json.loads(Path("store-after-upload.json").read_text()),
                                        upload, os.environ["GITHUB_SHA"])
        except (ValueError, OSError, TypeError, KeyError) as error:
            Path("store-processing-report.json").write_text(json.dumps({
                "application_source": config["app_source"], "controller_source": os.environ["GITHUB_SHA"],
                "qualified_run": config["qualified_run"], "processing_state": "VERIFICATION_FAILED",
                "apple_processing_confirmed": False, "app_store_submitted": False,
                "read_only": True, "error": str(error)
            }, indent=2) + "\n")
            raise
        if binary:
            receipt.update(boundary)
            receipt["store_listing_blocker"] = config["store_listing_blocker"]
        Path("store-processing-report.json").write_text(json.dumps(receipt, indent=2) + "\n")
        print("Apple build" + str(config["build"]) + " processing: " + receipt["processing_state"])
        if not receipt["apple_processing_confirmed"]:
            raise SystemExit(10)  # Pending is not success and never asks for another upload.
        return
    if operation == "source":
        verify_checkout(config, Path("hashiya-tools"))
        print("Actual application checkout is still the clean qualified source")
        return
    if operation == "engine":
        endpoint = f"repos/x6one/hashiya-ios/actions/runs/{config['qualified_run']}/artifacts?per_page=100"
        artifacts = json.loads(subprocess.check_output(["gh", "api", endpoint], text=True))["artifacts"]
        matches = [a for a in artifacts if a["name"] == ARTIFACT and not a["expired"]]
        if len(matches) != 1:
            raise ValueError("Expected one unexpired engine artifact from the qualified run")
        meta = matches[0]
        if not 0 < meta["size_in_bytes"] < MAX_ARCHIVE:
            raise ValueError("Engine archive size is outside its bounds")
        archive = Path("qualified-engine.zip")
        with archive.open("xb") as file:
            subprocess.run(["gh", "api", f"repos/x6one/hashiya-ios/actions/artifacts/{meta['id']}/zip"], stdout=file, check=True)
        receipt = extract_engine(archive, meta, config, Path("OfficeEngineCandidate"))
        Path("store-engine-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    else:
        receipt = write_provenance(config, Path("hashiya-tools"), Path("AppleDistribution"),
                                   json.loads(Path("store-engine-receipt.json").read_text()), os.environ["GITHUB_SHA"])
        if binary:
            receipt.update(boundary)
            receipt["store_listing_blocker"] = config["store_listing_blocker"]
        Path("AppleDistribution/store-publication-provenance.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print("Verified the qualified artifact/source boundary; no credential material logged")


if __name__ == "__main__":
    main()
