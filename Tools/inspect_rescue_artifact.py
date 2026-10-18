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
    for name in names:
        if name.endswith("-summary.json"):
            summary = json.loads(archive.read(name))
            print("RESCUE_SUMMARY " + json.dumps({
                "file": name,
                **{key: summary.get(key) for key in ("result", "passedTests", "failedTests", "totalTestCount")},
                "failures": [{"test": item.get("testName"), "failure": item.get("failureText", "")[:500]}
                    for item in summary.get("testFailures", [])],
            }))
        elif name.endswith("gesture-picker.log"):
            lines = archive.read(name).decode(errors="replace").splitlines()
            selected = [line for line in lines if any(term in line for term in
                ("TayyaRescueTransition", "DocumentNavigationBoundary", "TayyaRescueNavigation action", "TayyaRescueNavigation scroll"))]
            print("RESCUE_NATIVE_BEGIN")
            print("\n".join(selected[-120:]))
            print("RESCUE_NATIVE_END")
        elif name.endswith("build.log"):
            lines = archive.read(name).decode(errors="replace").splitlines()
            selected = [line for line in lines if any(term in line for term in
                ("Test Case '-[", "Executed ", ": error:", "TayyaGuidePDFFonts="))]
            print("RESCUE_TEST_LOG " + name)
            print("\n".join(line[:600] for line in selected[-100:]))
        elif name.endswith("manifest.json"):
            manifest = json.loads(archive.read(name))
            print("RESCUE_MANIFEST " + name + " " + json.dumps(manifest, ensure_ascii=False)[:600])
            if isinstance(manifest, list):
                folder = name.rsplit("/", 1)[0] + "/" if "/" in name else ""
                for group in manifest:
                    for attachment in group.get("attachments", []):
                        exported = folder + attachment["exportedFileName"]
                        human = attachment.get("suggestedHumanReadableName", "")
                        if "NativeScrollState" in human and exported in names:
                            print("RESCUE_RAIL " + human)
                            print(archive.read(exported).decode(errors="replace")[:22000])
    preview = os.environ.get("PREVIEW_PATH", "")
    if preview:
        if preview not in names or not preview.lower().endswith((".png", ".jpg", ".jpeg")):
            raise RuntimeError("Preview must name an observed image entry in this ZIP")
        image = archive.read(preview)
        if len(image) > 4000000:
            raise RuntimeError("Preview exceeds the bounded log output")
        print("RESCUE_PREVIEW_BASE64=" + base64.b64encode(image).decode())
