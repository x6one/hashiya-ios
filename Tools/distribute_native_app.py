"""Archive, verify and upload the native project on macOS, after preflight.

Signing credentials are read only from CI secrets. This does not submit an
App Store review or invite testers. Apple processing must be verified separately.
"""
import base64
import argparse
import datetime
import hashlib
import json
import os
import plistlib
import re
import secrets
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

TEAM = "ZUB6SJFQA3"
BUNDLE = "com.ahmadalawi.hashiya"


def run(args, operation, *, capture=False, env=None):
    result = subprocess.run(args, capture_output=capture, env=env)
    if result.returncode:
        # Do not include command arguments: security commands contain passwords.
        raise RuntimeError(f"{operation} failed with exit {result.returncode}")
    return result.stdout if capture else None


def write_private(path, data):
    path.write_bytes(data)
    path.chmod(0o600)


def validate_resources(app):
    for resource in ["fundamentalrc", "services.rdb", "udkapi.rdb", "offapi.rdb",
                     "share/fonts/truetype", "OfficeEngineNotices/engine-manifest.json",
                     "PrivacyInfo.xcprivacy"]:
        if not (app / resource).exists():
            raise RuntimeError(f"Release resource missing: {resource}")
    manifest = plistlib.loads((app / "PrivacyInfo.xcprivacy").read_bytes())
    if "NSPrivacyAccessedAPITypes" not in manifest:
        raise RuntimeError("Required-reason API declarations are missing")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive-only', action='store_true',
                        help='Verify a signed App Store IPA without transmitting it to Apple')
    args = parser.parse_args()
    readiness = json.loads(Path("Store/release-readiness.json").read_text())
    for gate in ([] if args.archive_only else ["privacy_audit_complete", "encryption_classification_complete"]):
        if readiness.get(gate) is not True:
            raise RuntimeError(f"Release gate is incomplete: {gate}")
    required = ["APPLE_DISTRIBUTION_P12_BASE64", "APPLE_DISTRIBUTION_P12_PASSWORD",
                "APPLE_PROVISIONING_PROFILE_BASE64"]
    if not args.archive_only:
        required += ["ASC_PRIVATE_KEY_BASE64", "ASC_KEY_ID", "ASC_ISSUER_ID"]
    if any(not os.environ.get(name) for name in required):
        raise RuntimeError("Apple distribution secrets have not been configured")
    if not args.archive_only and not re.fullmatch(r"[A-Z0-9]+", os.environ["ASC_KEY_ID"]):
        raise RuntimeError("Invalid App Store Connect key ID")
    unsigned_app = Path("NativeDeviceBuild/Build/Products/Release-iphoneos/Hashiya.app")
    validate_resources(unsigned_app)
    output = Path("../AppleDistribution").resolve()
    output.mkdir(exist_ok=False)
    original_keychains = run(["security", "list-keychains", "-d", "user"],
                             "Read keychain list", capture=True).decode()
    original_keychains = re.findall(r'"([^"]+)"', original_keychains)
    profile_path = None
    profile_installed = False
    with tempfile.TemporaryDirectory(prefix="tayya-signing-", dir=os.environ["RUNNER_TEMP"]) as folder:
        private = Path(folder)
        keychain = private / "distribution.keychain-db"
        password = secrets.token_urlsafe(32)
        try:
            p12 = private / "distribution.p12"
            profile = private / "distribution.mobileprovision"
            write_private(p12, base64.b64decode(os.environ[required[0]], validate=True))
            write_private(profile, base64.b64decode(os.environ[required[2]], validate=True))
            profile_info = plistlib.loads(run(["security", "cms", "-D", "-i", str(profile)],
                                               "Decode provisioning profile", capture=True))
            entitlements = profile_info["Entitlements"]
            prefix = profile_info["ApplicationIdentifierPrefix"][0]
            if (profile_info["TeamIdentifier"] != [TEAM]
                    or entitlements.get("application-identifier") != prefix + "." + BUNDLE
                    or entitlements.get("get-task-allow") is not False
                    or profile_info.get("ProvisionedDevices")
                    or profile_info.get("ProvisionsAllDevices")):
                raise RuntimeError("Expected an App Store distribution profile for Tayya's team and bundle")
            if profile_info["ExpirationDate"] <= datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None):
                raise RuntimeError("Distribution profile has expired")
            certificates = profile_info.get("DeveloperCertificates", [])
            if len(certificates) != 1:
                raise RuntimeError("Expected one distribution certificate in the profile")
            identity = hashlib.sha1(certificates[0]).hexdigest().upper()
            profile_uuid = profile_info["UUID"]
            if not re.fullmatch(r"[0-9A-Fa-f-]{36}", profile_uuid):
                raise RuntimeError("Invalid provisioning profile UUID")
            profile_directory = Path.home() / "Library/MobileDevice/Provisioning Profiles"
            profile_directory.mkdir(parents=True, exist_ok=True)
            profile_path = profile_directory / (profile_uuid + ".mobileprovision")
            if profile_path.exists():
                raise RuntimeError("Refusing to overwrite an existing provisioning profile")
            write_private(profile_path, profile.read_bytes())
            profile_installed = True
            run(["security", "create-keychain", "-p", password, str(keychain)], "Create ephemeral keychain", capture=True)
            run(["security", "set-keychain-settings", "-lut", "21600", str(keychain)], "Configure keychain", capture=True)
            run(["security", "unlock-keychain", "-p", password, str(keychain)], "Unlock keychain", capture=True)
            # Keep the stored PKCS12 encrypted with modern algorithms. Apple's
            # failed to import this container; decode it with OpenSSL 3 instead.
            # Decrypt only inside this private, per-run directory and import
            # the RSA key and certificate separately into the unlocked keychain.
            openssl = Path(run(["brew", "--prefix", "openssl@3"],
                               "Locate OpenSSL 3", capture=True).decode().strip()) / "bin/openssl"
            if not openssl.is_file():
                raise RuntimeError("OpenSSL 3 is required to decode the signing container")
            decoded_key = private / "decoded-key.pem"
            signing_key = private / "signing-key.pem"
            signing_certificate = private / "signing-certificate.pem"
            for path in [decoded_key, signing_key, signing_certificate]:
                write_private(path, b"")
            import_env = {**os.environ, "TAYYA_P12_IMPORT_PASSWORD": os.environ[required[1]]}
            run([str(openssl), "pkcs12", "-in", str(p12), "-passin", "env:TAYYA_P12_IMPORT_PASSWORD",
                 "-nocerts", "-noenc", "-out", str(decoded_key)],
                "Decode encrypted signing key", capture=True, env=import_env)
            run([str(openssl), "pkey", "-in", str(decoded_key), "-traditional", "-out", str(signing_key)],
                "Prepare Keychain-compatible RSA key", capture=True)
            run([str(openssl), "pkcs12", "-in", str(p12), "-passin", "env:TAYYA_P12_IMPORT_PASSWORD",
                 "-clcerts", "-nokeys", "-out", str(signing_certificate)],
                "Decode signing certificate", capture=True, env=import_env)
            for path in [signing_key, signing_certificate]:
                run(["security", "import", str(path), "-k", str(keychain),
                     "-T", "/usr/bin/codesign", "-T", "/usr/bin/security"],
                    "Import distribution identity component", capture=True)
            for path in [decoded_key, signing_key, signing_certificate]:
                path.unlink()
            run(["security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:", "-s", "-k", password,
                 str(keychain)], "Allow signing tools in ephemeral keychain", capture=True)
            run(["security", "list-keychains", "-d", "user", "-s", str(keychain), *original_keychains], "Set runner keychain list", capture=True)
            identities = run(["security", "find-identity", "-v", "-p", "codesigning", str(keychain)],
                             "Check matching private key", capture=True).decode()
            if identity not in identities:
                raise RuntimeError("The certificate private key does not match the App Store profile")
            # Command-line signing overrides affect every target, including
            # Swift package resource bundles that cannot use a provisioning
            # profile. Scope these settings to the application in the generated
            # native project, preserving its engine sources and resource script.
            native_spec = json.loads(Path("NativeOfficeProject.yml").read_text())
            app_settings = native_spec["targets"]["Hashiya"]["settings"]["base"]
            app_settings.update({"CODE_SIGN_STYLE": "Manual", "DEVELOPMENT_TEAM": TEAM,
                                 "CODE_SIGN_IDENTITY": identity,
                                 "PROVISIONING_PROFILE_SPECIFIER": profile_uuid})
            signing_spec = Path("NativeOfficeSigningProject.yml")
            try:
                write_private(signing_spec, (json.dumps(native_spec, indent=2) + "\n").encode())
                run(["xcodegen", "generate", "--spec", str(signing_spec)],
                    "Generate app-target signing settings", capture=True)
            finally:
                signing_spec.unlink(missing_ok=True)
            archive = output / "Tayya.xcarchive"
            run(["xcodebuild", "-project", "Hashiya.xcodeproj", "-scheme", "Hashiya", "-configuration", "Release",
                 "-sdk", "iphoneos", "-destination", "generic/platform=iOS", "-archivePath", str(archive),
                 "-derivedDataPath", "NativeDeviceBuild", "archive"], "Archive native Office app")
            options = private / "ExportOptions.plist"
            write_private(options, plistlib.dumps({"method": "app-store-connect", "destination": "export",
                "teamID": TEAM, "signingStyle": "manual", "signingCertificate": identity,
                "provisioningProfiles": {BUNDLE: profile_uuid}, "uploadSymbols": True, "stripSwiftSymbols": True}))
            exported = output / "Export"
            run(["xcodebuild", "-exportArchive", "-archivePath", str(archive), "-exportPath", str(exported),
                 "-exportOptionsPlist", str(options)], "Export App Store IPA")
            ipas = list(exported.glob("*.ipa"))
            if len(ipas) != 1:
                raise RuntimeError("Expected one exported IPA")
            unpacked = private / "verification"
            with zipfile.ZipFile(ipas[0]) as ipa:
                ipa.extractall(unpacked)
            apps = list((unpacked / "Payload").glob("*.app"))
            if len(apps) != 1:
                raise RuntimeError("Expected one signed app")
            app = apps[0]
            validate_resources(app)
            info = plistlib.loads((app / "Info.plist").read_bytes())
            if info["CFBundleIdentifier"] != BUNDLE or sorted(info["UIDeviceFamily"]) != [1, 2]:
                raise RuntimeError("Signed app identity or device families do not match")
            if not (app / "embedded.mobileprovision").is_file():
                raise RuntimeError("Signed app has no provisioning profile")
            run(["codesign", "--verify", "--deep", "--strict", str(app)], "Verify exported signature")
            details = run(["codesign", "-d", "--entitlements", ":-", str(app)],
                          "Inspect exported entitlements", capture=True)
            signed_entitlements = plistlib.loads(details)
            if signed_entitlements.get("application-identifier") != prefix + "." + BUNDLE or signed_entitlements.get("get-task-allow") is not False:
                raise RuntimeError("Exported entitlements do not match distribution")
            executable = app / info["CFBundleExecutable"]
            run(["xcrun", "lipo", str(executable), "-verify_arch", "arm64"], "Verify device architecture")
            with ipas[0].open("rb") as ipa_file:
                digest = hashlib.file_digest(ipa_file, "sha256").hexdigest()
            report = {"source_commit": os.environ["GITHUB_SHA"], "run": os.environ["GITHUB_RUN_ID"],
                "team": TEAM, "bundle_id": BUNDLE, "version": info["CFBundleShortVersionString"],
                "build": info["CFBundleVersion"], "code_signed": True, "sha256": digest,
                "archive_only": args.archive_only, "release_readiness": readiness,
                "installation": "App Store distribution signature; installation requires Apple processing and TestFlight or App Store distribution. Not directly installable.",
                "upload_accepted": False, "apple_processing_confirmed": False, "app_store_submitted": False}
            report_path = output / "distribution-report.json"
            report_path.write_text(json.dumps(report, indent=2) + "\n")
            if args.archive_only:
                return
            api_directory = private / "api"
            api_directory.mkdir(mode=0o700)
            write_private(api_directory / ("AuthKey_" + os.environ["ASC_KEY_ID"] + ".p8"),
                          base64.b64decode(os.environ["ASC_PRIVATE_KEY_BASE64"], validate=True))
            upload_env = {**os.environ, "API_PRIVATE_KEYS_DIR": str(api_directory)}
            auth = ["--apiKey", os.environ["ASC_KEY_ID"], "--apiIssuer", os.environ["ASC_ISSUER_ID"]]
            run(["xcrun", "altool", "--validate-app", "-f", str(ipas[0]), "-t", "ios", *auth],
                "Validate with App Store Connect", env=upload_env)
            run(["xcrun", "altool", "--upload-app", "-f", str(ipas[0]), "-t", "ios", *auth],
                "Upload to App Store Connect", env=upload_env)
            report["upload_accepted"] = True
            report_path.write_text(json.dumps(report, indent=2) + "\n")
        finally:
            # Cleanup never logs private key contents or passwords.
            subprocess.run(["security", "list-keychains", "-d", "user", "-s", *original_keychains], capture_output=True)
            if keychain.exists():
                subprocess.run(["security", "delete-keychain", str(keychain)], capture_output=True)
            if profile_installed and profile_path is not None and profile_path.exists():
                profile_path.unlink()
            shutil.rmtree(output / "Tayya.xcarchive", ignore_errors=True)


if __name__ == "__main__":
    main()
