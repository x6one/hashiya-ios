"""Bounded forensic reading of existing native CI artifacts; never runs app tests."""
import base64, hashlib, io, json, os, struct, urllib.error, urllib.request, zipfile
from pathlib import Path

REPO = "https://api.github.com/repos/x6one/hashiya-ios"
SOURCE = "df4ab1ddb7d5110eebf32a41ba00798098fda080"
RUN = 39286829941
ARTIFACTS = [12209710711, 12209366437]

def api(path):
    request = urllib.request.Request(REPO + path, headers={
        "Authorization": "Bearer " + os.environ["GH_TOKEN"],
        "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, newurl):
        return None

def download_location(identifier):
    request = urllib.request.Request(REPO + f"/actions/artifacts/{identifier}/zip",
        headers={"Authorization": "Bearer " + os.environ["GH_TOKEN"]})
    try:
        urllib.request.build_opener(NoRedirect).open(request, timeout=30)
    except urllib.error.HTTPError as error:
        if error.code != 302:
            raise RuntimeError("Artifact redirect unavailable") from None
        location = error.headers["Location"]
        if not location.startswith("https://"):
            raise RuntimeError("Non-HTTPS artifact redirect")
        return location
    raise RuntimeError("Expected artifact redirect")

class RemoteZip(io.RawIOBase):
    def __init__(self, url, size):
        self.url, self.size, self.position = url, size, 0
        self.cache, self.downloaded = [], 0
    def seekable(self): return True
    def tell(self): return self.position
    def seek(self, offset, whence=0):
        self.position = offset + (self.position if whence == 1 else self.size if whence == 2 else 0)
        return self.position
    def read(self, length=-1):
        start = self.position
        length = min(self.size-start, length if length >= 0 else self.size-start)
        if length <= 0: return b""
        for offset, data in self.cache:
            if offset <= start and start+length <= offset+len(data):
                self.position += length
                return data[start-offset:start-offset+length]
        end = min(self.size-1, start+max(length,65536)-1)
        if self.downloaded + end-start+1 > 20_000_000:
            raise RuntimeError("Artifact range-read cap exceeded")
        request = urllib.request.Request(self.url, headers={"Range":f"bytes={start}-{end}"})
        with urllib.request.urlopen(request, timeout=30) as response:
            if response.status != 206 or response.headers.get("Content-Range") != f"bytes {start}-{end}/{self.size}":
                raise RuntimeError("Exact HTTP range unavailable; full-body fallback prohibited")
            data = response.read(end-start+1)
        if len(data) != end-start+1: raise RuntimeError("Incomplete range")
        self.downloaded += len(data)
        self.cache.append((start,data)); self.position += length
        return data[:length]

root = Path("forensic-review"); root.mkdir()
identifier = 12209366437
metadata = api(f"/actions/artifacts/{identifier}")
if metadata["workflow_run"]["head_sha"] != SOURCE or metadata["workflow_run"]["id"] != RUN:
    raise RuntimeError("Unexpected artifact source")
remote = RemoteZip(download_location(identifier), metadata["size_in_bytes"])
with zipfile.ZipFile(remote) as archive:
    info = archive.getinfo("Screenshots/manifest.json")
    if info.file_size > 500000: raise RuntimeError("Manifest exceeds bound")
    data = archive.read(info)
    groups = json.loads(data)
    failed = [g for g in groups if "testNewMarginStrokesWorkAfterSplitResizeRotationAndExpansion" in g["testIdentifier"]]
    names = {"Screenshots/"+a["exportedFileName"] for g in failed for a in g["attachments"]}
    media = [{"path":i.filename,"bytes":i.file_size,"compressed":i.compress_size,"method":i.compress_type}
        for i in archive.infolist() if i.filename in names or i.filename.startswith("Screenshots/") and i.filename.endswith((".mp4",".mov",".heic",".jpeg",".jpg"))]
    report = {"source":SOURCE,"run":RUN,"artifact":identifier,"failed_groups":failed,"media":media,
        "range_bytes_received":remote.downloaded,"manifest_crc":"passed","manifest_sha256":hashlib.sha256(data).hexdigest(),
        "full_archive_sha256_verified":False}
    (root/"failed-media-index.json").write_text(json.dumps(report,indent=2)+"\n")
    print("FORENSIC_MEDIA_INDEX "+json.dumps(report,ensure_ascii=False),flush=True)
