"""Build a local, unmodified-PNG review of approved Studio vs real production.

Inputs are capture indexes, not generated mockups. Missing exact before matches
are shown explicitly; a different language/device/appearance is never substituted.
"""
import argparse
import hashlib
import html
import json
from pathlib import Path
import shutil
import struct


FIELDS = ("scene", "family", "orientation", "font_size", "color_mode", "language")
REQUIRED = (*FIELDS, "file", "source", "test_url", "sha256", "device")


def validated_capture(root, record):
    missing = [field for field in REQUIRED if not record.get(field)]
    if missing:
        raise ValueError("Incomplete capture metadata: " + ", ".join(missing))
    path = (root / record["file"]).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError("Capture path escapes evidence root")
    data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() != record["sha256"]:
        raise ValueError("Capture hash mismatch: " + record["file"])
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError("Expected original PNG: " + record["file"])
    width, height = struct.unpack(">II", data[16:24])
    if width <= 0 or height <= 0:
        raise ValueError("Empty screenshot")
    if len(record["source"]) != 40 or any(char not in "0123456789abcdef" for char in record["source"]):
        raise ValueError("Capture requires exact source SHA")
    if not record["test_url"].startswith("https://github.com/x6one/hashiya-ios/actions/runs/"):
        raise ValueError("Capture requires the actual repository's test link")
    return path, width, height


def build(before_root, before, after_root, after, output):
    if output.exists():
        raise ValueError("Review output must be new; existing evidence is never overwritten")
    # Validate every selected source before creating any deliverable.
    before_paths = {index: validated_capture(before_root, row) for index, row in enumerate(before)}
    after_paths = {index: validated_capture(after_root, row) for index, row in enumerate(after)}
    keys = {}
    for index, row in enumerate(before):
        keys.setdefault(tuple(row[field] for field in FIELDS), []).append(index)
    if not after:
        raise ValueError("No real production screenshots provided")
    output.mkdir(parents=True)
    images = output / "images"
    images.mkdir()
    pairs = []

    def copy(index, rows, paths, phase):
        row = dict(rows[index])
        path, width, height = paths[index]
        target = images / (phase + "-" + str(index + 1).zfill(3) + ".png")
        if not target.exists():
            shutil.copyfile(path, target)
        row.update(file=target.relative_to(output).as_posix(), pixel_width=width, pixel_height=height, phase=phase)
        return row

    for index, row in enumerate(after):
        matches = keys.get(tuple(row[field] for field in FIELDS), [])
        approved = None
        requested = row.get("before_sha256")
        if requested:
            matches = [match for match in matches if before[match]["sha256"] == requested]
            if len(matches) != 1:
                raise ValueError("Explicit approved comparison does not match capture configuration")
        if len(matches) == 1:
            approved = copy(matches[0], before, before_paths, "approved-design")
        pairs.append({"before": approved, "after": copy(index, after, after_paths, "real-production"),
                      "comparison": "exact capture context" if approved else "no unique approved screenshot in the same context"})

    def card(row, title):
        if row is None:
            return '<article><h3>' + title + '</h3><p>لا توجد صورة معتمدة مطابقة لهذا السياق في المدخلات.</p></article>'
        esc = lambda value: html.escape(str(value), quote=True)
        details = " · ".join(str(row[field]) for field in ("device", "orientation", "font_size", "color_mode", "language"))
        return ('<article><h3>' + title + '</h3><a href="' + esc(row["file"]) + '"><img loading="lazy" src="' +
                esc(row["file"]) + '" alt="' + esc(row["scene"]) + '"></a><p>' + esc(details) +
                '</p><code>' + esc(row["source"]) + '</code><p><a href="' + esc(row["test_url"]) +
                '">اختبار المصدر</a></p><details><summary>بيانات الصورة الأصلية</summary><pre>' +
                esc(json.dumps(row, ensure_ascii=False, indent=2)) + '</pre></details></article>')

    sections = []
    for pair in pairs:
        row = pair["after"]
        search = html.escape(" ".join(str(row[field]) for field in FIELDS), quote=True)
        sections.append('<section data-search="' + search + '"><h2>' + html.escape(row["scene"]) +
                        '</h2><div class="pair">' + card(pair["before"], "التصميم المعتمد") +
                        card(row, "التطبيق الحقيقي") + '</div></section>')
    document = '''<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>Tayya Studio — Production Review</title>
<style>body{font-family:system-ui;background:#F8F7F3;color:#282C2B;margin:0;padding:16px}header{max-width:1200px;margin:auto}input{font:inherit;padding:12px;border:1px solid #244C43;border-radius:12px;width:min(90%,600px)}section{max-width:1200px;margin:24px auto}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}article{background:white;border-radius:16px;padding:16px;min-width:0}img{display:block;width:100%;height:auto;max-height:85vh;object-fit:contain}code,pre{direction:ltr;text-align:left;display:block;overflow-wrap:anywhere;white-space:pre-wrap}a{color:#244C43}p{line-height:1.6}@media(max-width:700px){.pair{grid-template-columns:1fr}}[hidden]{display:none!important}</style>
<header><h1>طَيّة — مقارنة الدمج الحقيقي</h1><p>صور PNG الأصلية دون قص أو تدوير أو تعديل. الصور تفتح بحجمها الأصلي. شاشة الصوت هنا من التطبيق الحقيقي؛ لا تثبت لقطات الشاشة التقاط ميكروفون جهاز فعلي.</p><label>تصفية حسب الشاشة أو الجهاز أو اللغة <input id="search" type="search" placeholder="iPhone · dark · en · notes"></label></header>'''
    document += "".join(sections)
    document += '''<script>document.getElementById('search').addEventListener('input',function(){const q=this.value.toLowerCase().split(/\\s+/).filter(Boolean);document.querySelectorAll('section').forEach(s=>{s.hidden=!q.every(v=>s.dataset.search.toLowerCase().includes(v))})})</script></html>'''
    (output / "index.html").write_text(document, encoding="utf-8")
    (output / "captures.json").write_text(json.dumps(pairs, ensure_ascii=False, indent=2), encoding="utf-8")
    manifest = {path.relative_to(output).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                for path in sorted(output.rglob("*")) if path.is_file()}
    (output / "SHA256.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return pairs


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before-root", type=Path, required=True)
    parser.add_argument("--before-index", type=Path, required=True)
    parser.add_argument("--after-root", type=Path, required=True)
    parser.add_argument("--after-index", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = build(args.before_root, json.loads(args.before_index.read_text()), args.after_root,
                   json.loads(args.after_index.read_text()), args.output)
    print(json.dumps({"productionCaptures": len(result), "exactComparisons": sum(pair["before"] is not None for pair in result)}))
