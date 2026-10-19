"""Read bounded ZIP entries with HTTP ranges; never downloads raw xcresult ZIPs."""
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import re
import urllib.error
import urllib.request
import zipfile

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

class RangeFile(io.RawIOBase):
    block_size = 131072
    def __init__(self, url):
        self.url, self.position, self.cache = url, 0, {}
        self.network_bytes, self.requests = 0, 0
        data, start, total = self.fetch("bytes=-65557", 65557)
        self.size, self.tail_start, self.tail = total, start, data
    def fetch(self, value, limit):
        request = urllib.request.Request(self.url, headers={"Range": value})
        with urllib.request.urlopen(request, timeout=45) as response:
            if response.status != 206:
                raise RuntimeError("Server did not honor bounded Range; full download refused")
            match = re.fullmatch(r"bytes (\d+)-(\d+)/(\d+)", response.headers.get("Content-Range", ""))
            if not match:
                raise RuntimeError("Missing exact Content-Range")
            start, end, total = map(int, match.groups())
            data = response.read(limit + 1)
            if len(data) > limit or len(data) != end - start + 1:
                raise RuntimeError("Range length mismatch")
        self.network_bytes += len(data); self.requests += 1
        return data, start, total
    def seekable(self):
        return True
    def readable(self):
        return True
    def tell(self):
        return self.position
    def seek(self, offset, whence=0):
        position = offset if whence == 0 else self.position + offset if whence == 1 else self.size + offset
        if position < 0:
            raise ValueError("Negative seek")
        self.position = position
        return position
    def read(self, size=-1):
        size = self.size - self.position if size < 0 else min(size, max(0, self.size - self.position))
        if size > 2_100_000:
            raise RuntimeError("Selected ZIP read exceeds diagnostic evidence cap")
        start, end = self.position, self.position + size
        if start >= self.tail_start and end <= self.size:
            result = self.tail[start-self.tail_start:end-self.tail_start]
        else:
            chunks = []
            cursor = start
            while cursor < end:
                block = cursor // self.block_size
                if block not in self.cache:
                    first = block * self.block_size
                    last = min(self.size, first + self.block_size) - 1
                    payload, actual, total = self.fetch(f"bytes={first}-{last}", self.block_size)
                    if actual != first or total != self.size:
                        raise RuntimeError("Archive changed during range inspection")
                    if len(self.cache) >= 24:
                        self.cache.pop(next(iter(self.cache)))
                    self.cache[block] = payload
                payload = self.cache[block]
                first = block * self.block_size
                count = min(end-cursor, len(payload)-(cursor-first))
                if count <= 0:
                    raise RuntimeError("Incomplete range block")
                chunks.append(payload[cursor-first:cursor-first+count]); cursor += count
            result = b"".join(chunks)
        self.position = end
        return result

artifact = int(os.environ["ARTIFACT_ID"])
request = urllib.request.Request(f"https://api.github.com/repos/x6one/hashiya-ios/actions/artifacts/{artifact}/zip",
    headers={"Authorization": "Bearer " + os.environ["GH_TOKEN"], "Accept": "application/vnd.github+json"})
try:
    response = urllib.request.build_opener(NoRedirect).open(request, timeout=30)
except urllib.error.HTTPError as error:
    if error.code != 302:
        raise
    location = error.headers["Location"]
else:
    response.close()
    raise RuntimeError("Expected unsigned artifact-storage redirect")
if not location.startswith("https://"):
    raise RuntimeError("Artifact redirect must use HTTPS")
remote = RangeFile(location)
selected = []
with zipfile.ZipFile(remote) as archive:
    names = archive.namelist()
    print("RESCUE_ENTRIES " + json.dumps([{"path": item.filename, "bytes": item.file_size}
        for item in archive.infolist() if not item.filename.endswith(".xcresult.zip")])[:22000])
    def read(name, maximum=250000):
        entry = archive.getinfo(name)
        if entry.file_size > maximum:
            raise RuntimeError("Selected evidence entry exceeds limit: " + name)
        selected.append(name)
        return archive.read(name)  # zipfile validates this entry's CRC.
    for name in names:
        if name.endswith("-summary.json"):
            summary = json.loads(read(name))
            print("RESCUE_SUMMARY " + json.dumps(summary)[:12000])
        if name.endswith("gesture-picker.log"):
            lines = read(name, 2_000_000).decode(errors="replace").splitlines()
            start, end = os.environ.get("NATIVE_WINDOW_START", ""), os.environ.get("NATIVE_WINDOW_END", "")
            window = [line for line in lines if start and end and start <= line[:23] <= end]
            selected_native = [line for line in lines if "TayyaRescueNavigation scroll" in line]
            print("RESCUE_NATIVE_WINDOW_BEGIN")
            print("\n".join(window[:300])[:70000])
            print("RESCUE_NATIVE_WINDOW_END")
            print("RESCUE_NATIVE_SCROLL " + "\n".join(selected_native[-40:]))
        if name.endswith("-attachments/manifest.json"):
            manifest = json.loads(read(name))
            parent = name.rsplit("/", 1)[0] + "/"
            for group in manifest:
                for item in group.get("attachments", []):
                    human = item.get("suggestedHumanReadableName", "")
                    print("RESCUE_ATTACHMENT " + json.dumps({"name": human, "path": parent + item["exportedFileName"]}))
                    if any(term in human for term in ("NativePaletteDismissal", "NativeScrollState", "RedPixelFailureMeasurement", "RedPixelPolling")) and item["exportedFileName"].endswith(".txt"):
                        print("RESCUE_ATTACHMENT_TEXT " + human)
                        print(read(parent + item["exportedFileName"], 64000).decode(errors="replace")[:24000])
    name = next((name for name in names if name.endswith("saved-drawings/manifest.json")), None)
    if name:
        manifest = json.loads(read(name))
        print("RESCUE_SAVED_DRAWINGS " + json.dumps(manifest)[:24000])
        destination = os.environ.get("SAVED_DRAWINGS_OUTPUT", "")
        if destination:
            output = Path(destination); output.mkdir(parents=True, exist_ok=True)
            folder = name.rsplit("/", 1)[0] + "/"
            retained = 0
            for record in manifest.get("drawings", []):
                filename = record["drawing"]
                if Path(filename).name != filename or not filename.endswith(".drawing"):
                    raise RuntimeError("Drawing must be a direct file")
                data = read(folder + filename, 2_000_000)
                if hashlib.sha256(data).hexdigest() != record["drawing_sha256"]:
                    raise RuntimeError("Saved drawing SHA256 mismatch")
                retained += len(data)
                if retained > 8_000_000:
                    raise RuntimeError("Saved drawing extraction exceeds total cap")
                (output / filename).write_bytes(data)
            (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    preview = os.environ.get("PREVIEW_PATH", "")
    if preview:
        if preview not in names or not preview.lower().endswith((".png", ".jpg", ".jpeg")):
            raise RuntimeError("Preview must name an observed image")
        print("RESCUE_PREVIEW_BASE64=" + base64.b64encode(read(preview, 2_000_000)).decode())
print("RESCUE_RANGE_PROVENANCE " + json.dumps({"artifact": artifact,
    "provided_archive_sha256": os.environ.get("PROVIDED_SHA256"),
    "full_archive_sha256_independently_checked": False, "selected_entry_crc_checked": True,
    "archive_bytes": remote.size, "network_bytes": remote.network_bytes,
    "requests": remote.requests, "selected": selected}))
