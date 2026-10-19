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

import plistlib, subprocess
root = Path("forensic-review"); root.mkdir()
identifier = 12209366437
metadata = api(f"/actions/artifacts/{identifier}")
if metadata["workflow_run"]["head_sha"] != SOURCE or metadata["workflow_run"]["id"] != RUN:
    raise RuntimeError("Unexpected artifact source")
remote = RemoteZip(download_location(identifier), metadata["size_in_bytes"])
records = []
with zipfile.ZipFile(remote) as archive:
    video_name = "Screenshots/79AFB129-21E8-4861-A38D-374C6BDDE8CC.mp4"
    info = archive.getinfo(video_name)
    if info.file_size>12_000_000: raise RuntimeError("Video exceeds case bound")
    video = archive.read(info)
    path = root/"failed-test.mp4"; path.write_bytes(video)
    records.append({"path":video_name,"sha256":hashlib.sha256(video).hexdigest(),"bytes":len(video),"zip_crc":"passed"})
    for filename in ["B2DC144F-7630-4E8A-9ED1-42D9FF9C4EFB","C360ECDA-36F1-42CE-A763-B34619B5E171","447900BD-A17D-4A74-AB27-A89E38DD3F1A"]:
        name="Screenshots/"+filename; info=archive.getinfo(name)
        if info.file_size>10000: raise RuntimeError("Synthesized event exceeds bound")
        data=archive.read(info); decoded=plistlib.loads(data)
        strings=[x for x in decoded.get("$objects",[]) if isinstance(x,str)]
        print("FORENSIC_EVENT "+json.dumps({"path":name,"strings":strings,"sha256":hashlib.sha256(data).hexdigest()},ensure_ascii=False),flush=True)
    probe=json.loads(subprocess.check_output(["ffprobe","-v","error","-show_format","-show_streams","-of","json",str(path)]))
    print("FORENSIC_VIDEO "+json.dumps({"duration":probe["format"]["duration"],
        "streams":[{k:s.get(k) for k in ["codec_name","width","height","r_frame_rate"]} for s in probe["streams"]],
        "video":records[0]}),flush=True)
    for number,offset in enumerate([11.6,12.4,12.85,13.35,14.5]):
        output=root/f"frame-{number}.png"
        subprocess.run(["ffmpeg","-v","error","-ss",str(offset),"-i",str(path),"-frames:v","1","-compression_level","6",str(output)],check=True)
        data=output.read_bytes()
        if len(data)>500000: raise RuntimeError("Frame exceeds log-image bound")
        width,height=struct.unpack(">II",data[16:24]);encoded=base64.b64encode(data).decode("ascii")
        chunks=[encoded[i:i+12000] for i in range(0,len(encoded),12000)];token=f"pad-video-{number}"
        print("FORENSIC_IMAGE_META "+json.dumps({"token":token,"source":SOURCE,"artifact":identifier,
            "path":video_name,"relative_seconds":offset,"width":width,"height":height,
            "sha256":hashlib.sha256(data).hexdigest(),"bytes":len(data),"chunks":len(chunks),"pixel_transform":"native decoded frame; no resize"}),flush=True)
        for index,chunk in enumerate(chunks):
            print("FORENSIC_IMAGE_CHUNK "+json.dumps({"token":token,"index":index,"data":chunk}),flush=True)
report={"source":SOURCE,"run":RUN,"artifact":identifier,"range_bytes_received":remote.downloaded,
    "full_archive_sha256_verified":False,"scope":"Selected original video ZIP CRC and SHA; native decoded frames","retained":records}
(root/"provenance.json").write_text(json.dumps(report,indent=2)+"\n")
print("FORENSIC_PROVENANCE "+json.dumps(report),flush=True)
