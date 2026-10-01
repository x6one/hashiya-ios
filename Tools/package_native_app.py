"""Retain the unsigned native Office app after simulator and device build gates.

Does not sign, provision, upload to TestFlight or publish an App Store build.
"""
import argparse
import hashlib
import json
import os
import plistlib
import shutil
import subprocess
from pathlib import Path


def package(app: Path, output: Path) -> None:
    app = app.resolve(strict=True)
    info = plistlib.loads((app / "Info.plist").read_bytes())
    if sorted(info["UIDeviceFamily"]) != [1, 2]:
        raise ValueError("The candidate must support iPhone and iPad")
    if (app / "embedded.mobileprovision").exists():
        raise ValueError("Expected the explicitly unsigned device build")
    executable = app / info["CFBundleExecutable"]
    subprocess.run(["xcrun", "lipo", str(executable), "-verify_arch", "arm64"], check=True)
    build = subprocess.check_output(["xcrun", "vtool", "-show-build", str(executable)], text=True)
    if "platform IOS\n" not in build:
        raise ValueError("This is not an iOS device executable")
    for required in ["fundamentalrc", "services.rdb", "share/fonts/truetype", "OfficeEngineNotices"]:
        if not (app / required).exists():
            raise ValueError(f"Native engine resource missing: {required}")
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    payload = output / "Payload"
    payload.mkdir()
    shutil.copytree(app, payload / "Hashiya.app")
    name = "Tayya-native-office-unsigned.ipa"
    subprocess.run(["zip", "-qry", name, "Payload"], cwd=output, check=True)
    with (output / name).open("rb") as file:
        sha = hashlib.file_digest(file, "sha256").hexdigest()
    (output / "Tayya-native-office.sha256").write_text(sha + "  " + name + "\n")
    signature = subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], capture_output=True, text=True)
    identity = subprocess.run(["codesign", "-dv", "--verbose=4", str(app)], capture_output=True, text=True)
    report = {"commit": os.environ["GITHUB_SHA"], "run": os.environ["GITHUB_RUN_ID"],
        "version": info["CFBundleShortVersionString"], "build": info["CFBundleVersion"],
        "bundle_identifier": info["CFBundleIdentifier"], "device_families": info["UIDeviceFamily"],
        "architecture": "arm64", "platform": "iphoneos", "contains_provisioning_profile": False,
        "code_signing_allowed": False, "codesign_verify_exit": signature.returncode,
        "codesign_diagnostic": (signature.stdout + signature.stderr).strip(),
        "signature_details": (identity.stdout + identity.stderr).strip(),
        "native_office": "Experimental local Office to PDF conversion; device runtime not yet tested.",
        "engine_source": json.loads((app / "OfficeEngineNotices/engine-manifest.json").read_text())["source"],
        "installation": "Requires external signing with a valid certificate and provisioning profile. Not directly installable.",
        "sha256": sha}
    (output / "Tayya-native-office-signing.json").write_text(json.dumps(report, indent=2) + "\n")
    shutil.rmtree(payload)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    package(args.app, args.output)
