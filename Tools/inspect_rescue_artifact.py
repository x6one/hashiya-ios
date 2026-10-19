"""Read an existing Actions artifact; never runs or changes native tests."""
import base64
import hashlib
import io
import json
import os
import urllib.error
import urllib.request
import zipfile

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

artifact = int(os.environ["ARTIFACT_ID"])
url = f"https://api.github.com/repos/x6one/hashiya-ios/actions/artifacts/{artifact}/zip"
request = urllib.request.Request(url, headers={
    "Authorization": "Bearer " + os.environ["GH_TOKEN"],
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
})
try:
    response = urllib.request.build_opener(NoRedirect).open(request, timeout=30)
except urllib.error.HTTPError as error:
    if error.code != 302:
        raise
    location = error.headers["Location"]
    if not location.startswith("https://"):
        raise RuntimeError("Artifact redirect must use HTTPS")
    # Do not forward the GitHub credential to the artifact storage host.
    response = urllib.request.urlopen(location, timeout=60)
with response:
    payload = response.read()
digest = hashlib.sha256(payload).hexdigest()
if digest != os.environ["EXPECTED_SHA256"]:
    raise RuntimeError("Artifact SHA256 mismatch")
print("RESCUE_ARTIFACT_SHA256=" + digest)
with zipfile.ZipFile(io.BytesIO(payload)) as archive:
    if archive.testzip() is not None:
        raise RuntimeError("Artifact ZIP CRC failure")
    names = archive.namelist()
    images = [{"path": item.filename, "bytes": item.file_size} for item in archive.infolist()
        if item.filename.lower().endswith((".png", ".jpg", ".jpeg"))]
    print("RESCUE_IMAGES " + json.dumps({"total": len(images), "entries": images[:100]}))
    # Preserve small original diagnostic entries once so subsequent readers
    # do not download raw xcresult ZIPs or recordings merely to inspect text.
    subset = os.environ.get("SMALL_EVIDENCE_OUTPUT", "")
    if subset:
        from pathlib import Path, PurePosixPath
        output = Path(subset); output.mkdir(parents=True, exist_ok=True)
        retained, copied, omitted = 0, [], []
        for info in archive.infolist():
            parts = PurePosixPath(info.filename)
            if info.is_dir(): continue
            if parts.is_absolute() or ".." in parts.parts:
                raise RuntimeError("Unsafe artifact entry")
            if info.file_size > 4_000_000 or info.filename.lower().endswith((".mp4", ".zip")) or retained + info.file_size > 16_000_000:
                omitted.append({"path": info.filename, "bytes": info.file_size})
                continue
            raw = archive.read(info)
            target = output.joinpath(*parts.parts)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw)
            copied.append({"path": info.filename, "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()})
            retained += len(raw)
        (output / "subset-provenance.json").write_text(json.dumps({"source_artifact": artifact,
            "source_artifact_sha256": digest, "source_zip_crc": "passed",
            "copied": copied, "omitted": omitted, "retained_bytes": retained}, indent=2) + "\n")
        print("RESCUE_SMALL_EVIDENCE " + json.dumps({"files": len(copied), "bytes": retained, "omitted": omitted}))
    attachment_budget = 90000
    rail_attachment_budget = 160000
    for name in names:
        if name.endswith("-summary.json"):
            summary = json.loads(archive.read(name))
            print("RESCUE_SUMMARY " + json.dumps({
                "file": name,
                "devices": summary.get("devicesAndConfigurations"),
                **{key: summary.get(key) for key in ("result", "passedTests", "failedTests", "totalTestCount")},
                "failures": [{"test": item.get("testName"), "failure": item.get("failureText", "")[:1600]}
                    for item in summary.get("testFailures", [])],
            }))
        elif name.endswith("gesture-picker.log"):
            lines = archive.read(name).decode(errors="replace").splitlines()
            print("RESCUE_NATIVE_HEADER " + json.dumps({"lines": len(lines), "first": lines[:4]}))
            selected = [line for line in lines if any(term in line for term in
                ("TayyaRescueInput", "TayyaRescueNavigation observe", "TayyaRescueTransition", "DocumentNavigationBoundary acquire", "DocumentNavigationBoundary restore", "TayyaRescueNavigation action", "TayyaRescueNavigation scroll"))]
            print("RESCUE_NATIVE_BEGIN")
            print("\n".join(selected[-400:]))
            print("RESCUE_NATIVE_END")
            start = os.environ.get("NATIVE_WINDOW_START", "")
            end = os.environ.get("NATIVE_WINDOW_END", "")
            if start and end:
                window = [line for line in lines if start <= line[:23] <= end]
                print("RESCUE_NATIVE_WINDOW_BEGIN")
                print("\n".join(window[:400])[:80000])
                print("RESCUE_NATIVE_WINDOW_END")
            color = [line for line in lines if "ColorPicker" in line]
            print("RESCUE_COLOR_SERVICE_BEGIN")
            print("\n".join(color[:100] + color[-40:]))
            print("RESCUE_COLOR_SERVICE_END")
        elif name.endswith("build.log"):
            lines = archive.read(name).decode(errors="replace").splitlines()
            selected = [line for line in lines if any(term in line for term in
                ("Test Case '-[", "Executed ", ": error:", "TayyaGuidePDFFonts=", "NativeInkEvidence", "Start Test at", "Test Suite '", 'Tap "inkColor"'))]
            print("RESCUE_TEST_LOG " + name)
            print("RESCUE_BUILD_INVOCATION " + "\n".join(lines[:8]))
            for index, line in enumerate(lines):
                if "background assertion" in line.lower():
                    print("RESCUE_ASSERTION_CONTEXT_BEGIN")
                    print("\n".join(lines[max(0, index-18):index+10])[:16000])
                    print("RESCUE_ASSERTION_CONTEXT_END")
            print("\n".join(line[:1600] for line in selected[-100:]))
            failures = [index for index, line in enumerate(lines) if ": error:" in line]
            for index in failures[:8]:
                print("RESCUE_FAILURE_CONTEXT " + name)
                print("\n".join(lines[max(0, index-16):index+8])[:10000])
        elif name.endswith("manifest.json"):
            manifest = json.loads(archive.read(name))
            print("RESCUE_MANIFEST " + name + " " + json.dumps(manifest, ensure_ascii=False)[:600])
            if isinstance(manifest, list):
                folder = name.rsplit("/", 1)[0] + "/" if "/" in name else ""
                for group in manifest:
                    for attachment in group.get("attachments", []):
                        exported = folder + attachment["exportedFileName"]
                        human = attachment.get("suggestedHumanReadableName", "")
                        print("RESCUE_ATTACHMENT " + json.dumps({"test": group.get("testName", group.get("testIdentifier")), "name": human, "path": exported}))
                        relevant = ("NativeScrollState", "NativeInkState", "NativePalettePresentation", "NativePaletteDismissal",
                            "RedPixelPolling", "RedPixelFailureMeasurement", "TapGeometry")
                        if any(term in human for term in relevant) and exported in names:
                            rail = "NativeScrollState" in human
                            budget = rail_attachment_budget if rail else attachment_budget
                            if budget <= 0:
                                print("RESCUE_ATTACHMENT_OMITTED " + human)
                                continue
                            limit = min(32000 if rail else 16000, budget)
                            raw = archive.read(exported).decode(errors="replace")
                            body = raw[:limit]
                            print("RESCUE_ATTACHMENT_TEXT " + human)
                            print(body)
                            print("RESCUE_ATTACHMENT_TRUNCATED_CHARS=" + str(max(0, len(raw) - len(body))))
                            if rail:
                                rail_attachment_budget -= len(body)
                            else:
                                attachment_budget -= len(body)
    saved_manifest = next((name for name in names if name.endswith("saved-drawings/manifest.json")), None)
    if saved_manifest:
        manifest = json.loads(archive.read(saved_manifest))
        print("RESCUE_SAVED_DRAWINGS " + json.dumps(manifest, ensure_ascii=False)[:24000])
        destination = os.environ.get("SAVED_DRAWINGS_OUTPUT", "")
        if destination:
            from pathlib import Path
            output = Path(destination); output.mkdir(parents=True, exist_ok=True)
            folder = saved_manifest.rsplit("/", 1)[0] + "/"
            retained = 0
            for record in manifest.get("drawings", []):
                filename = record["drawing"]
                if Path(filename).name != filename or not filename.endswith(".drawing"):
                    raise RuntimeError("Drawing must be a direct file")
                data = archive.read(folder + filename)
                if len(data) > 2_000_000 or retained + len(data) > 8_000_000:
                    raise RuntimeError("Saved drawing evidence exceeds bounds")
                if hashlib.sha256(data).hexdigest() != record["drawing_sha256"]:
                    raise RuntimeError("Saved drawing SHA256 mismatch")
                (output / filename).write_bytes(data)
                retained += len(data)
            (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
            print("RESCUE_SAVED_DRAWINGS_EXTRACTED=" + str(len(manifest.get("drawings", []))))
    preview = os.environ.get("PREVIEW_PATH", "")
    if preview:
        if preview not in names or not preview.lower().endswith((".png", ".jpg", ".jpeg")):
            raise RuntimeError("Preview must name an observed image entry in this ZIP")
        image = archive.read(preview)
        if len(image) > 4000000:
            raise RuntimeError("Preview exceeds the bounded log output")
        print("RESCUE_PREVIEW_BASE64=" + base64.b64encode(image).decode())
