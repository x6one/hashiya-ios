"""Assemble unmodified native screenshots and their exact source provenance."""
import argparse
import hashlib
import html
import json
import pathlib
import shutil


def logical_name(name):
    replacements = {
        "UpdatedPDF-Light-Portrait": "Light-document-Portrait",
        "UpdatedPDF-Light-Landscape": "Light-document-Landscape",
        "UpdatedPDF---dark-Portrait": "Dark-document-Portrait",
        "UpdatedPDF---english-Portrait": "English-document",
        "UpdatedPDF---large-type-Portrait": "Accessibility-document",
        "Accessible-WholeLabels-document": "Accessibility-document",
        "Accessible-WholeLabels-margin": "Accessibility-margin",
    }
    name = name.removeprefix("Studio-")
    return replacements.get(name, name)


def build(source_root, output, plan_file):
    plan = json.loads(plan_file.read_text())
    output.mkdir(parents=True, exist_ok=False)
    (output / "images").mkdir()
    all_images = []
    preferred = {}
    for source in plan["sources"]:
        folders = sorted((source_root / source["folder"]).rglob("source.json"))
        if len(folders) != 2:
            raise ValueError("Expected actual iPhone and iPad evidence in " + source["folder"])
        for metadata in folders:
            root = metadata.parent
            provenance = json.loads(metadata.read_text())
            assert provenance["source"] == source["sha"]
            hashes = {x["file"]: x["sha256"] for x in provenance["images"]}
            manifest = json.loads((root / "Screenshots/manifest.json").read_text())
            for test in manifest:
                for attachment in test["attachments"]:
                    original = attachment["exportedFileName"]
                    name = attachment["suggestedHumanReadableName"]
                    if not original.endswith(".png") or not name.startswith("Studio-"):
                        continue
                    assert pathlib.PurePosixPath(original).name == original
                    path = root / "Screenshots" / original
                    digest = hashlib.sha256(path.read_bytes()).hexdigest()
                    assert hashes["Screenshots/" + original] == digest
                    name = name.split("_0_")[0]
                    target = f"images/{len(all_images) + 1:03}-{provenance['family']}.png"
                    shutil.copyfile(path, output / target)
                    record = {"file": target, "name": name, "logical_name": logical_name(name),
                              "family": provenance["family"], "source": source["sha"],
                              "run": source["run"], "test": test["testIdentifier"], "sha256": digest}
                    all_images.append(record)
                    preferred[(record["family"], record["logical_name"])] = record
    pictures = list(preferred.values())
    (output / "all-images.json").write_text(json.dumps(all_images, ensure_ascii=False, indent=2) + "\n")
    (output / "evidence.json").write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n")
    payload = json.dumps(pictures, ensure_ascii=False).replace("<", "\\u003c")
    cards = []
    for picture in pictures:
        name = html.escape(picture["logical_name"])
        family = picture["family"]
        cards.append(f'<article data-family="{family}"><a href="{picture["file"]}"><img loading="lazy" src="{picture["file"]}" alt="{name}"></a><h3>{family} · {name}</h3><a href="https://github.com/x6one/hashiya-ios/actions/runs/{picture["run"]}">{picture["source"][:7]} · المصدر والاختبار</a></article>')
    page = '''<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Tayya Studio 2.0 — مراجعة التصميم</title>
<style>body{margin:0;background:#F8F7F3;color:#282C2B;font:16px system-ui,sans-serif}header,main{max-width:1400px;margin:auto;padding:24px}h1{color:#244C43}p{line-height:1.8;max-width:980px}nav{display:flex;gap:8px;flex-wrap:wrap}button{min-height:44px;padding:8px 24px;border:1px solid #244C43;border-radius:12px;background:white;color:#244C43;font:inherit;cursor:pointer}button[aria-pressed=true]{background:#244C43;color:white}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:24px}article{background:white;border:1px solid #DEE3DE;border-radius:16px;padding:16px}img{display:block;width:100%;height:500px;object-fit:contain;background:#E9EFEA;border-radius:8px}h3{font-size:14px;direction:ltr;overflow-wrap:anywhere}a{color:#244C43}article[hidden]{display:none}footer{padding:24px;text-align:center}</style>
<header><h1>طَيّة · Tayya Studio 2.0</h1><p>معاينات SwiftUI فعلية من محاكيات الآيفون والآيباد. اضغط الصورة لرؤيتها بحجمها الأصلي. واجهات الإنتاج وملفات المستخدم لم تتغير. الصوت بيانات تفاعلية تجريبية؛ لا يُستخدم الميكروفون هنا.</p><p>الصور الأساسية محفوظة من تشغيل المعاينات، وتُستبدل الصورة عند توفر لقطة أحدث للإصلاح الموجّه. تفاصيل كل صورة وبصمتها في <a href="all-images.json">سجل الصور الأصلي</a>، والنتائج وحدود التحقق في <a href="evidence.json">سجل الأدلة</a>. هذه ليست دعوى باختبار إنتاج شامل على SHA واحد.</p><nav><button aria-pressed="true" data-filter="all">الجهازان</button><button aria-pressed="false" data-filter="iPhone">iPhone</button><button aria-pressed="false" data-filter="iPad">iPad</button></nav></header><main class="grid">CARDS</main><footer>مرحلة التصميم فقط · بانتظار اعتماد الشكل قبل تعديل واجهات الإنتاج</footer><script>const pictures=PAYLOAD;for(const b of document.querySelectorAll('[data-filter]'))b.onclick=()=>{for(const x of document.querySelectorAll('[data-filter]'))x.setAttribute('aria-pressed',String(x===b));for(const a of document.querySelectorAll('article'))a.hidden=b.dataset.filter!=='all'&&a.dataset.family!==b.dataset.filter;};</script></html>'''
    (output / "index.html").write_text(page.replace("CARDS", "".join(cards)).replace("PAYLOAD", payload))
    print(json.dumps({"retained_original_images": len(all_images), "preferred_images": len(pictures), "families": sorted({x['family'] for x in pictures})}))


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("source_root", type=pathlib.Path)
    p.add_argument("output", type=pathlib.Path)
    p.add_argument("plan_file", type=pathlib.Path)
    a = p.parse_args()
    build(a.source_root, a.output, a.plan_file)
