"""Consume a qualified Office artifact and attest the separately checked-out app.

No signing credentials, Apple API calls or changes to the original build/signing
helpers belong here. Only the explicitly authorized Store controller may run it.
"""
import argparse
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
    if (config.get("app_id"), config.get("bundle_id"), config.get("version"), str(config.get("build"))) != (
            "6818288428", "com.ahmadalawi.hashiya", "0.6.0", "13"):
        raise ValueError("Only the authorized Tayya0.6.0(13) target is allowed")
    for key in ("app_source", "app_tree"):
        if not re.fullmatch("[a-f0-9]{40}", config.get(key, "")):
            raise ValueError("Invalid application source pin")
    if not str(config.get("qualified_run", "")).isdigit():
        raise ValueError("Invalid qualified run")


def verify_authorization(config, environment, event):
    validate_target(config)
    if (config.get("publish_binary") is not True or environment.get("GITHUB_EVENT_NAME") != "push"
            or environment.get("GITHUB_REPOSITORY") != "x6one/hashiya-ios"
            or environment.get("GITHUB_REF") != "refs/heads/store/tayya-app-store-content"
            or "[store:publish-approved]" not in event.get("head_commit", {}).get("message", "")):
        raise ValueError("Explicit authorized Store publication request is absent")


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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=["engine", "source", "receipt"])
    args = parser.parse_args()
    config = json.loads(Path("Store/publication.json").read_text())
    event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
    verify_authorization(config, os.environ, event)
    verify_listing(json.loads(Path("StoreDraft/store-listing-report.json").read_text()), config)
    if args.operation == "source":
        verify_checkout(config, Path("hashiya-tools"))
        print("Actual application checkout is still the clean qualified source")
        return
    if args.operation == "engine":
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
        Path("AppleDistribution/store-publication-provenance.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print("Verified the qualified artifact/source boundary; no credential material logged")


if __name__ == "__main__":
    main()
