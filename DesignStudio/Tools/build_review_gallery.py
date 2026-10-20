"""Assemble unmodified native screenshots and their exact source provenance."""
import argparse
import hashlib
import html
import json
import pathlib
import shutil


def capture_metadata(name):
    """Historical captures encode launch traits; fresh captures require native sidecars."""
    lower = name.lower()
    extreme = 'extremetype' in lower or 'compactaccessible' in lower
    accessible = 'accessibility' in lower or 'accessible-' in lower or 'large-type' in lower
    return {'orientation': 'landscape' if 'landscape' in lower or 'compactaccessible' in lower else 'portrait',
            'font_size': 'AX5' if extreme else 'AX2' if accessible else 'default',
            'color_mode': 'dark' if 'dark' in lower else 'light',
            'language': 'en' if 'english' in lower else 'ar',
            'metadata_origin': 'legacy test name and launch arguments'}


def caption(record):
    traits = ' · '.join(str(record[key]) for key in ('device', 'orientation', 'font_size', 'color_mode', 'language'))
    return (f'<p>{html.escape(traits)}</p><p dir="ltr">{html.escape(record["source"])}<br>'
            f'<a href="{record["test_url"]}">{html.escape(record["test"])}</a></p>')


def logical_name(name):
    replacements = {
        "UpdatedPDF-Light-Portrait": "Light-document-Portrait",
        "UpdatedPDF-Light-Landscape": "Light-document-Landscape",
        "UpdatedPDF---dark-Portrait": "Dark-document-Portrait",
        "UpdatedPDF---english-Portrait": "English-document",
        "UpdatedPDF---large-type-Portrait": "Accessibility-document",
        "Accessible-WholeLabels-document": "Accessibility-document",
        "Accessible-WholeLabels-margin": "Accessibility-margin",
        "Polish-Real-PageThumbnails": "Document-PageThumbnails",
    }
    name = name.removeprefix("Studio-")
    return replacements.get(name, name)


def build(source_root, output, plan_file):
    plan = json.loads(plan_file.read_text())
    output.mkdir(parents=True, exist_ok=False)
    (output / "images").mkdir()
    all_images = []
    preferred = {}
    previous = {}
    polished = {}
    documents = []
    for source in plan["sources"]:
        folders = sorted((source_root / source["folder"]).rglob("source.json"))
        if len(folders) != 2:
            raise ValueError("Expected actual iPhone and iPad evidence in " + source["folder"])
        for metadata in folders:
            root = metadata.parent
            provenance = json.loads(metadata.read_text())
            assert provenance["source"] == source["sha"]
            device = {'deviceName': provenance['family']}
            summary_file = root / 'summary.json'
            if summary_file.exists():
                summary = json.loads(summary_file.read_text())
                if required := source.get('required_test_count'):
                    if (summary.get('passedTests'), summary.get('failedTests'), summary.get('skippedTests'), summary.get('expectedFailures')) != (required, 0, 0, 0):
                        raise ValueError('Incomplete native approval gate for ' + provenance['family'])
                configurations = summary.get('devicesAndConfigurations', [])
                if configurations:
                    device = configurations[0]['device']
            if source.get('required_test_count') and not summary_file.exists():
                raise ValueError('Missing native approval summary')
            hashes = {x["file"]: x["sha256"] for x in provenance["images"]}
            manifest = json.loads((root / "Screenshots/manifest.json").read_text())
            for test in manifest:
                native_metadata = {}
                for attachment in test['attachments']:
                    filename = attachment['exportedFileName']
                    human = attachment['suggestedHumanReadableName']
                    if human.startswith('Studio-Metadata-') and filename.endswith('.json'):
                        assert pathlib.PurePosixPath(filename).name == filename
                        details = json.loads((root / 'Screenshots' / filename).read_text())
                        native_metadata['Studio-' + details['screen']] = details
                for attachment in test["attachments"]:
                    original = attachment["exportedFileName"]
                    name = attachment["suggestedHumanReadableName"]
                    if source['folder'] == 'polish' and name.startswith('Studio-Diverse-Native-PDF') and original.endswith('.pdf'):
                        assert pathlib.PurePosixPath(original).name == original
                        (output / 'documents').mkdir(exist_ok=True)
                        target_pdf = f'documents/{provenance["family"]}-Diverse-Native-PDF.pdf'
                        shutil.copyfile(root / 'Screenshots' / original, output / target_pdf)
                        documents.append({'file': target_pdf, 'source': source['sha'], 'run': source['run'],
                                          'sha256': hashlib.sha256((output / target_pdf).read_bytes()).hexdigest()})
                    if not original.endswith(".png") or not name.startswith("Studio-"):
                        continue
                    assert pathlib.PurePosixPath(original).name == original
                    path = root / "Screenshots" / original
                    digest = hashlib.sha256(path.read_bytes()).hexdigest()
                    assert hashes["Screenshots/" + original] == digest
                    name = name.split("_0_")[0]
                    if source.get('require_native_metadata') and name not in native_metadata:
                        raise ValueError('Missing native capture metadata for ' + name)
                    target = f"images/{len(all_images) + 1:03}-{provenance['family']}.png"
                    shutil.copyfile(path, output / target)
                    record = {"file": target, "name": name, "logical_name": logical_name(name),
                              "family": provenance["family"], "source": source["sha"],
                              "run": source["run"], "test": test["testIdentifier"], "sha256": digest}
                    record.update(native_metadata.get(name, capture_metadata(name)))
                    record['device'] = device.get('deviceName', provenance['family'])
                    record['os_version'] = device.get('osVersion')
                    record['test_url'] = f'https://github.com/x6one/hashiya-ios/actions/runs/{source["run"]}'
                    if job := source.get('jobs', {}).get(provenance['family']):
                        record['test_url'] += f'/job/{job}'
                    all_images.append(record)
                    key = (record["family"], record["logical_name"])
                    preferred[key] = record
                    (polished if source["folder"] == "polish" else previous)[key] = record
    pictures = list(polished.values() if polished else preferred.values())
    (output / "all-images.json").write_text(json.dumps(all_images, ensure_ascii=False, indent=2) + "\n")
    (output / "evidence.json").write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n")
    (output / "documents.json").write_text(json.dumps(documents, indent=2) + "\n")
    payload = json.dumps(pictures, ensure_ascii=False).replace("<", "\\u003c")
    def cards_for(records):
        cards = []
        for picture in records:
            name = html.escape(picture["logical_name"])
            family = picture["family"]
            cards.append(f'<article data-family="{family}"><a href="{picture["file"]}"><img loading="lazy" src="{picture["file"]}" alt="{name}"></a><h3>{html.escape(pathlib.PurePosixPath(picture["file"]).name)} · {name}</h3>{caption(picture)}</article>')
        return ''.join(cards)
    page = '''<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Tayya Studio 2.0 — مراجعة التصميم</title>
<style>body{margin:0;background:#F8F7F3;color:#282C2B;font:16px system-ui,sans-serif}header,main{max-width:1400px;margin:auto;padding:24px}h1{color:#244C43}p{line-height:1.8;max-width:980px}nav{display:flex;gap:8px;flex-wrap:wrap}button{min-height:44px;padding:8px 24px;border:1px solid #244C43;border-radius:12px;background:white;color:#244C43;font:inherit;cursor:pointer}button[aria-pressed=true]{background:#244C43;color:white}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,280px),1fr));gap:24px}article{min-width:0;background:white;border:1px solid #DEE3DE;border-radius:16px;padding:16px}img{display:block;width:100%;height:500px;object-fit:contain;background:#E9EFEA;border-radius:8px}article p{overflow-wrap:anywhere}h3{font-size:14px;direction:ltr;overflow-wrap:anywhere}a{color:#244C43}article[hidden]{display:none}footer{padding:24px;text-align:center}</style>
<header><h1>طَيّة · Tayya Studio 2.0</h1><p>معاينات SwiftUI فعلية من محاكيات الآيفون والآيباد. اضغط الصورة لرؤيتها بحجمها الأصلي. واجهات الإنتاج وملفات المستخدم لم تتغير. الصوت بيانات تفاعلية تجريبية؛ لا يُستخدم الميكروفون هنا.</p><p>تعرض هذه الصفحة صور مصدر الاعتماد الحالي فقط؛ الصور السابقة محفوظة في الأرشيف والمقارنة. تفاصيل كل صورة وبصمتها في <a href="all-images.json">سجل الصور الأصلي</a>، والنتائج وحدود التحقق في <a href="evidence.json">سجل الأدلة</a>. نتائج نموذج التصميم وحدود التحقق موثقة بصورة منفصلة عن اختبارات التطبيق الأساسي.</p><p><a href="Final-Approval.md">نتائج الاعتماد النهائي</a> · <a href="Original160-Audit.md">تدقيق الصور السابقة</a> · <a href="Native-Visual-Audit.md">تدقيق صور الاعتماد</a> · <a href="Gallery-Build.json">مصدر حزمة المراجعة</a> · <a href="Review.md">المراجعة السابقة</a> · <a href="Polish-Review.md">الأسباب والإصلاحات</a> · <a href="Design-System.md">نظام التصميم</a> · <a href="Actions.md">توزيع الأزرار</a> · <a href="Polish-Plan.md">خطة الصقل</a></p><nav><button aria-pressed="true" data-filter="all">الجهازان</button><button aria-pressed="false" data-filter="iPhone">iPhone</button><button aria-pressed="false" data-filter="iPad">iPad</button></nav></header><main class="grid">CARDS</main><footer>مرحلة التصميم فقط · بانتظار اعتماد الشكل قبل تعديل واجهات الإنتاج</footer><script>const pictures=PAYLOAD;for(const b of document.querySelectorAll('[data-filter]'))b.onclick=()=>{for(const x of document.querySelectorAll('[data-filter]'))x.setAttribute('aria-pressed',String(x===b));for(const a of document.querySelectorAll('article'))a.hidden=b.dataset.filter!=='all'&&a.dataset.family!==b.dataset.filter;};</script></html>'''
    page = page.replace('</header>', '<p>الخط: default = الحجم الافتراضي، AX2 = خط إتاحة كبير، AX5 = أكبر خط إتاحة.</p><p><a href="index.html">صور الاعتماد الحالية</a> · <a href="history.html">أرشيف جميع الصور الأصلية</a></p></header>')
    (output / "index.html").write_text(page.replace("CARDS", cards_for(pictures)).replace("PAYLOAD", payload))
    history_payload = json.dumps(all_images, ensure_ascii=False).replace('<', '\\u003c')
    history_page = page.replace('تعرض هذه الصفحة صور مصدر الاعتماد الحالي فقط؛ الصور السابقة محفوظة في الأرشيف والمقارنة.', 'يعرض هذا الأرشيف جميع الصور الأصلية السابقة والحالية، ولكل صورة مصدرها المستقل.')
    (output / 'history.html').write_text(history_page.replace('CARDS', cards_for(all_images)).replace('PAYLOAD', history_payload))
    if documents:
        index = output / 'index.html'
        links = ' · '.join(f'<a href="{record["file"]}">{html.escape(pathlib.PurePosixPath(record["file"]).name)}</a>' for record in documents)
        index.write_text(index.read_text().replace('</header>', '<p>مستند PDF الأصلي المستخدم للتحقق: ' + links + '</p></header>'))
    if polished:
        references = set(plan.get("reference_images", []))
        selected = {pathlib.PurePosixPath(record["file"]).name: record for record in all_images
                    if pathlib.PurePosixPath(record["file"]).name in references}
        if references != selected.keys():
            raise ValueError("A requested original review reference is missing")
        comparison_previous = dict(previous)
        for record in selected.values():
            comparison_previous[(record["family"], record["logical_name"])] = record
        write_comparison(output, comparison_previous, polished)
        index = output / 'index.html'
        index.write_text(index.read_text().replace('</header>', '<p><a href="compare.html">مقارنة الصور قبل وبعد الصقل</a></p></header>'))
    print(json.dumps({"retained_original_images": len(all_images), "preferred_images": len(pictures), "families": sorted({x['family'] for x in pictures})}))


def write_comparison(output, previous, polished):
    def original(record, heading):
        if record is None:
            return '<div><p>معاينة إضافية؛ لا توجد لقطة سابقة مطابقة.</p></div>'
        return (f'<div><h3>{heading} · {html.escape(pathlib.PurePosixPath(record["file"]).name)}</h3><a href="{record["file"]}"><img loading="lazy" src="{record["file"]}" alt="{html.escape(record["logical_name"])}"></a>'
                + caption(record) + '</div>')
    pairs = []
    for key, current in polished.items():
        pairs.append(f'<section><h2>{html.escape(key[0] + " · " + key[1])}</h2><div class="pair">'
                     + original(previous.get(key), 'قبل الصقل') + original(current, 'بعد الصقل') + '</div></section>')
    page = ('<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
            '<title>Tayya — قبل وبعد الصقل</title><style>body{font:16px system-ui;background:#F8F7F3;color:#282C2B;margin:24px}h1,h2,a{color:#244C43}'
            '.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}.pair>div{background:white;border-radius:16px;padding:16px;min-width:0}'
            'img{width:100%;height:650px;object-fit:contain}p{overflow-wrap:anywhere}section{margin:32px 0}h2{font-size:18px;direction:ltr}'
            '@media(max-width:650px){.pair{grid-template-columns:1fr}img{height:auto}}</style><h1>طَيّة — مقارنة قبل وبعد</h1>'
            '<p>صور أصلية من المحاكيات. لكل صورة Commit وتشغيل مستقل. الصوت نموذج تفاعلي تجريبي.</p><a href="index.html">جميع الصور</a>'
            + ''.join(pairs) + '</html>')
    (output / 'compare.html').write_text(page)


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("source_root", type=pathlib.Path)
    p.add_argument("output", type=pathlib.Path)
    p.add_argument("plan_file", type=pathlib.Path)
    a = p.parse_args()
    build(a.source_root, a.output, a.plan_file)
