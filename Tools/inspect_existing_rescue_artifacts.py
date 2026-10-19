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

def emit(kind, value):
    print("FORENSIC_" + kind + " " + json.dumps(value, ensure_ascii=False), flush=True)

root = Path("forensic-review"); root.mkdir()
reports = []
for identifier in ARTIFACTS:
    metadata = api(f"/actions/artifacts/{identifier}")
    if metadata["workflow_run"]["head_sha"] != SOURCE or metadata["workflow_run"]["id"] != RUN:
        raise RuntimeError("Unexpected artifact source")
    remote = RemoteZip(download_location(identifier), metadata["size_in_bytes"])
    retained = []
    folder = root / str(identifier); folder.mkdir()
    with zipfile.ZipFile(remote) as archive:
        inventory = archive.infolist()
        small = [i for i in inventory if i.file_size <= 500000]
        emit("INVENTORY", {"artifact":identifier,"maestro":[
            {"path":i.filename,"bytes":i.file_size} for i in small if i.filename.startswith("MaestroResults/")]})
        images = []
        def read_entry(info):
            if info.file_size > 500000: raise RuntimeError("Entry exceeds cap")
            data = archive.read(info)  # ZIP entry CRC checked by ZipExtFile.
            digest = hashlib.sha256(data).hexdigest()
            retained.append({"path":info.filename,"bytes":len(data),"sha256":digest,"zip_crc":"passed"})
            (folder / (digest + Path(info.filename).suffix)).write_bytes(data)
            return data
        for info in small:
            name = info.filename
            selected = name.endswith(("TestResults-summary.json","MaestroResults/report.xml","NativeFailure/collection.json"))
            selected = selected or (name.startswith("MaestroResults/") and (name.endswith("maestro.log") or (Path(name).name.startswith("commands") and name.endswith(".json"))))
            selected = selected or (name.startswith("MaestroResults/") and "hierarchy" in name.lower() and name.endswith((".json",".xml")))
            if selected:
                data = read_entry(info)
                limit = 30000 if (Path(name).name.startswith("commands") and name.endswith(".json")) else 16000
                content = data.decode("utf-8",errors="replace")
                if name.endswith("maestro.log"): content = content[-limit:]
                elif (Path(name).name.startswith("commands") and name.endswith(".json")) and len(content)>limit:
                    content = content[:3000] + "\\n[MIDDLE OMITTED]\\n" + content[-27000:]
                else: content = content[:limit]
                emit("FILE",{"artifact":identifier,"path":name,"content":content,"text_truncated":len(data)>limit})
        maestro_png = [i for i in small if i.filename.startswith("MaestroResults/") and i.filename.endswith(".png")]
        groups = set()
        for info in maestro_png:
            parent = info.filename.rsplit("/",1)[0]
            if parent not in groups and len(groups)<3:
                images.append(info); groups.add(parent)
        if identifier == 12209366437:
            manifest_info = next((i for i in small if i.filename == "Screenshots/manifest.json"),None)
            if manifest_info:
                groups_json = json.loads(read_entry(manifest_info))
                for group in groups_json:
                    if "testNewMarginStrokesWorkAfterSplitResizeRotationAndExpansion" in group["testIdentifier"]:
                        candidates = [a for a in group["attachments"] if a["exportedFileName"].endswith(".png")]
                        candidates.sort(key=lambda a:not a.get("isAssociatedWithFailure",False))
                        for attachment in candidates[:2]:
                            info = archive.getinfo("Screenshots/"+attachment["exportedFileName"])
                            if info.file_size<=500000: images.append(info)
        for number, info in enumerate(images):
            data = read_entry(info)
            if data[:8] != b"\x89PNG\r\n\x1a\n": continue
            width,height = struct.unpack(">II",data[16:24])
            token = f"{identifier}-{number}"
            encoded = base64.b64encode(data).decode("ascii")
            chunks = [encoded[i:i+12000] for i in range(0,len(encoded),12000)]
            emit("IMAGE_META",{"token":token,"artifact":identifier,"path":info.filename,
                "mime":"image/png","width":width,"height":height,"sha256":hashlib.sha256(data).hexdigest(),
                "bytes":len(data),"chunks":len(chunks),"pixel_transform":"none"})
            for index,chunk in enumerate(chunks):
                emit("IMAGE_CHUNK",{"token":token,"index":index,"data":chunk})
    report = {"artifact":identifier,"source":SOURCE,"run":RUN,
        "range_bytes_received":remote.downloaded,"artifact_metadata_digest":metadata.get("digest"),
        "full_archive_sha256_verified":False,"scope":"Exact HTTPS byte ranges; selected ZIP entry CRC and SHA256",
        "retained":retained}
    reports.append(report); emit("PROVENANCE",report)
(root/"provenance.json").write_text(json.dumps(reports,indent=2)+"\n")
