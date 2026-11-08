"""Package genuine iPad photography: preserve every original PNG byte and EXIF."""
import argparse
import hashlib
from html import escape
import json
from pathlib import Path
import shutil
import struct

from Tools.collect_integration_captures import collect

APP_SOURCE = 'd45457bdd216265b11d58ba844fcda22fb6297d9'
SCENES = {
    'Library': 'المكتبة', 'Sections': 'الأقسام', 'Library-Review': 'المراجعة في المكتبة',
    'Settings': 'الإعدادات', 'Backup-Restore': 'النسخ الاحتياطي والاستعادة',
    'Library-Trash': 'المحذوفات', 'New-Notebook': 'إنشاء دفتر وقوالب الورق', 'Office-Preview': 'معاينة مستند Office',
    'Editor': 'محرر PDF', 'Pen-Tools': 'القلم والرسم المحفوظ', 'Favorite-Pens': 'الأقلام المفضلة',
    'Text-Editor': 'إضافة النص وتنسيقه', 'Selection': 'أدوات التحديد', 'PDF-Table': 'صفحة جدول',
    'PDF-Illustration-Ink': 'صفحة صورة وتعليقات بالقلم', 'PDF-Blank': 'صفحة فارغة للكتابة',
    'Thumbnails': 'مصغرات الصفحات الحقيقية', 'Focus': 'وضع التركيز', 'Document-Actions': 'إجراءات المستند',
    'Paper-Templates': 'إضافة ورقة وقوالب الكتابة', 'Notes-Expanded': 'الملاحظات المستقلة النصية',
    'Notes-Ink': 'الملاحظات بخط اليد', 'Notes-Pages': 'إدارة صفحات الملاحظات',
    'Notes-Split': 'تقسيم المستند والملاحظات', 'Notes-Split-Ink': 'الرسم في التقسيم',
    'Recording-Active': 'تسجيل صوت مرتبط بالصفحة والكتابة', 'Recording-Markers': 'التسجيل والعلامات الزمنية',
    'Recording-Playback': 'تشغيل الصوت والتنقل الزمني', 'Recording-Rename': 'إعادة تسمية التسجيل',
    'Flashcard-Editor': 'إنشاء بطاقة تعليمية', 'Flashcards-Question': 'مراجعة السؤال', 'Flashcards-Answer': 'إظهار الإجابة',
}


def build(root, rows, output):
    expected = {(scene, mode, direction) for scene in SCENES for mode in ['light', 'dark'] for direction in ['portrait', 'landscape']}
    keys = [(r['scene'], r['color_mode'], r['orientation']) for r in rows]
    missing = expected - set(keys)
    if missing:
        raise ValueError('Missing genuine capture contexts: ' + str(sorted(missing)))
    if len(keys) != len(set(keys)) or set(keys) != expected:
        raise ValueError('Duplicate or unexpected capture contexts')
    verified = []
    for row in rows:
        path = (root / row['file']).resolve()
        if not path.is_relative_to(root.resolve()):
            raise ValueError('Original path escapes the native evidence')
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != row['sha256'] or data[:8] != b'\x89PNG\r\n\x1a\n':
            raise ValueError('Original bytes or hash changed')
        dimensions = struct.unpack('>II', data[16:24])
        if dimensions != (row['png_width'], row['png_height']) or row['family'] != 'iPad':
            raise ValueError('Original native dimensions/family mismatch')
        display = (2064, 2752) if row['orientation'] == 'portrait' else (2752, 2064)
        if (row['display_pixel_width'], row['display_pixel_height']) != display:
            raise ValueError('Original must be the full-resolution actual iPad Pro13 display')
        verified.append((row, path))
    output.mkdir(parents=True, exist_ok=False)
    records, cards = [], []
    for row, original in sorted(verified, key=lambda item: (item[0]['color_mode'], item[0]['orientation'], list(SCENES).index(item[0]['scene']))):
        index = list(SCENES).index(row['scene']) + 1
        relative = Path('Originals') / row['color_mode'] / row['orientation'] / f"{index:02d}-{row['scene']}.png"
        target = output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(original, target)
        if hashlib.sha256(target.read_bytes()).hexdigest() != row['sha256']:
            raise ValueError('Original copy verification failed')
        saved = dict(row, file=relative.as_posix(), feature_name_ar=SCENES[row['scene']], application_source=APP_SOURCE)
        records.append(saved)
        mode = 'فاتح' if row['color_mode'] == 'light' else 'داكن'
        direction = 'طولي' if row['orientation'] == 'portrait' else 'عرضي'
        title = SCENES[row['scene']]
        cards.append(f'<article data-mode="{row["color_mode"]}" data-direction="{row["orientation"]}" data-title="{escape(title)}"><h2>{escape(title)}</h2><p>{mode} · {direction} · {escape(row["device"])}</p><a href="{relative.as_posix()}"><img loading="lazy" src="{relative.as_posix()}" alt="{escape(title)}"></a><p>{row["display_pixel_width"]} × {row["display_pixel_height"]} · PNG أصلي</p><a href="{escape(row["test_url"])}">اختبار التصوير</a><details><summary>المصدر والبصمة</summary><code>{escape(row["source"])}</code><br><code>{row["sha256"]}</code></details></article>')
    style = 'body{margin:0;background:#F8F7F3;color:#282C2B;font:16px system-ui}header{padding:24px;background:#244C43;color:white}nav{position:sticky;top:0;background:#fff;padding:12px;display:flex;gap:8px;flex-wrap:wrap;z-index:2}select,input{padding:12px;border:1px solid #c4cfc8;border-radius:8px;font:inherit;max-width:90%}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,340px),1fr));gap:20px;padding:16px}article{padding:16px;background:white;border-radius:12px;min-width:0}img{display:block;width:100%;height:auto}h2{font-size:20px}p{line-height:1.6}code{font-size:11px;overflow-wrap:anywhere}a{color:#244C43}[hidden]{display:none!important}'
    script = "function filter(){for(const c of document.querySelectorAll('article'))c.hidden=(m.value&&c.dataset.mode!==m.value)||(d.value&&c.dataset.direction!==d.value)||!c.dataset.title.includes(q.value)}for(const e of [m,d,q])e.addEventListener('input',filter)"
    page = '<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>طَيّة — صور iPad الأصلية</title><style>' + style + '</style><header><h1>طَيّة — صور الميزات على iPad</h1><p>128 صورة حقيقية · 32 شاشة × الفاتح والداكن × الطولي والعرضي. افتح أي صورة لحفظ PNG الأصلي كاملًا.</p><p>المصدر البرمجي: ' + APP_SOURCE + '</p></header><nav><select id="m"><option value="">كل الألوان</option value="light">فاتح</option><option value="dark">داكن</option></select><select id="d"><option value="">كل الاتجاهات</option><option value="portrait">طولي</option><option value="landscape">عرضي</option></select><input id="q" placeholder="اسم الميزة" aria-label="البحث عن ميزة"></nav><main>' + ''.join(cards) + '</main><script>' + script + '</script></html>'
    (output / 'index.html').write_text(page, encoding='utf-8')
    (output / 'features.json').write_text(json.dumps(records, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    (output / 'SHA256SUMS').write_text(''.join(r['sha256'] + '  ' + r['file'] + '\n' for r in records))
    (output / 'README.txt').write_text('صور حقيقية من تطبيق طَيّة الإنتاجي في وضع Debug على محاكي iPad Pro13، ببيانات عرض معزولة. لم تستخدم واجهات DesignStudio.\nافتح index.html للمعاينة أو Originals لملفات PNG الأصلية بلا إطارات أو قص أو تدوير أو إعادة تحجيم. قد يحتفظ PNG بوسم اتجاه EXIF أصلي؛ استخدم عارضًا يدعمه.\nالتسجيل يستخدم AVFoundation في المحاكي؛ الصور لا تثبت جودة الميكروفون على جهاز حقيقي. معاينة Office مصورة، ولا تدّعي اختبار تحويل Office على جهاز فعلي.\nلم يتغير كود التطبيق أو بيانات المستخدم أو Build15 المرفوع. التصوير منفصل عن اعتماد إصدار جديد.\n', encoding='utf-8')
    return records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for flag in ['captures', 'jobs', 'output']:
        parser.add_argument('--' + flag, type=Path, required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--run', type=int, required=True)
    args = parser.parse_args()
    jobs = json.loads(args.jobs.read_text())['jobs']
    rows = []
    for mode in ['light', 'dark']:
        job = [j for j in jobs if j['name'] == f'Native iPad ({mode})' and j['run_id'] == args.run and j['conclusion'] == 'success']
        if len(job) != 1:
            raise ValueError('Each color requires its own completed genuine native capture job')
        prefix = 'ipad-feature-' + mode
        root = args.captures / prefix
        proof = json.loads((root / 'provenance.json').read_text())
        if proof != dict(source=args.source, family='iPad', run=args.run):
            raise ValueError('Actual capture provenance mismatch')
        for row in collect(root, args.source, 'iPad', args.run, job[0]['id']):
            if row['color_mode'] != mode:
                raise ValueError('Actual launch appearance differs from requested job')
            row['file'] = prefix + '/' + row['file']
            rows.append(row)
    records = build(args.captures, rows, args.output)
    archive = shutil.make_archive(str(args.output), 'zip', args.output.parent, args.output.name)
    print(json.dumps(dict(original_pngs=len(records), archive=archive, application_source=APP_SOURCE)))


if __name__ == '__main__':
    main()
