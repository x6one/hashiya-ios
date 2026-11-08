"""Package genuine iPad photography: preserve every original PNG byte and EXIF."""
import argparse
import hashlib
from html import escape
import json
import os
from pathlib import Path
import shutil
import struct

from Tools.collect_integration_captures import collect, stage

APP_SOURCE = 'd45457bdd216265b11d58ba844fcda22fb6297d9'
SCENES = {
    'Library': 'المكتبة', 'Sections': 'الأقسام', 'Library-Review': 'المراجعة في المكتبة',
    'Settings': 'الإعدادات', 'Backup-Restore': 'النسخ الاحتياطي والاستعادة',
    'Library-Trash': 'المحذوفات', 'New-Notebook': 'إنشاء دفتر وقوالب الورق', 'Office-Preview': 'واجهة Office — قيود معاينة المحاكي',
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
    'Library-Search': 'البحث في النصوص والملاحظات', 'Import-Files': 'استيراد PDF وOffice من الملفات',
    'Export-PDF': 'تصدير ومشاركة PDF الحقيقي', 'Backup-Share': 'تصدير ومشاركة النسخة الاحتياطية',
}



def verified_core_cases(summary, tests, mode):
    """Certify individual passing cases; NEVER relabel the failed original run."""
    if mode not in ('light', 'dark'):
        raise ValueError('Unknown actual appearance')
    color = mode.title()
    expected = {f'StudioProductionCaptureTests/testIPad{color}{direction}{feature}()'
                for direction in ['Portrait', 'Landscape'] for feature in ['Audio', 'Cards', 'Document', 'Library', 'Notes']}
    excluded = {key for key in expected if key.endswith('Audio()')}
    if mode == 'dark':
        excluded |= {'StudioProductionCaptureTests/testIPadDarkPortraitDocument()', 'StudioProductionCaptureTests/testIPadDarkPortraitLibrary()'}
    pending, actual = list(tests['testNodes']), {}
    while pending:
        node = pending.pop()
        pending.extend(node.get('children', []))
        if node.get('nodeType') == 'Test Case':
            key = node['nodeIdentifier']
            if key in actual:
                raise ValueError('Duplicated actual test case')
            actual[key] = node.get('result')
    if set(actual) != expected or any(actual[key] != ('Failed' if key in excluded else 'Passed') for key in expected):
        raise ValueError('Unexpected, failed, skipped or incomplete original test result')
    if summary.get('result') != 'Failed' or summary.get('totalTestCount') != 10 or summary.get('passedTests') != 10-len(excluded) or summary.get('failedTests') != len(excluded) or summary.get('skippedTests') != 0 or summary.get('expectedFailures') != 0:
        raise ValueError('Original summary and native test case tree disagree')
    failures = summary.get('testFailures', [])
    if len(failures) != len(excluded) or {r['testIdentifierString'] for r in failures} != excluded:
        raise ValueError('Unexpected original failure inventory')
    for row in failures:
        text = row['failureText']
        if row['testIdentifierString'].endswith('Audio()'):
            if not all(v in text for v in ['pauseLinkedRecording', 'Multiple matching elements', 'recordingStrip', 'CollectionView']):
                raise ValueError('Original audio failure is not the proven ambiguous capture query')
        elif 'Capture waits for native orientation and compositor readiness' not in text:
            raise ValueError('Original capture failure differs from the reviewed native surface readiness')
    return sorted(expected-excluded)


def stage_baseline(raw, output, source, run, mode):
    evidence = raw / ('ipad-feature-failure-' + mode) / 'PhotoEvidence'
    summary = json.loads((evidence / 'summary.json').read_text())
    tests = json.loads((evidence / 'tests.json').read_text())
    selected = verified_core_cases(summary, tests, mode)
    device = json.loads((evidence / 'ipad-device.json').read_text())
    if device['application_source'] != APP_SOURCE or device['app_tree'] != '2eb2a2ac53b5678768ed9d9cf6926295163d0acd':
        raise ValueError('Original actual application identity mismatch')
    manifest = json.loads((evidence / 'Screenshots/manifest.json').read_text())
    chosen = [r for r in manifest if r['testIdentifier'] in selected]
    if {r['testIdentifier'] for r in chosen} != set(selected) or len(chosen) != len(selected):
        raise ValueError('Original selected attachments do not cover individually passed cases')
    scope = output.parent / ('CoreScopeInput-' + mode)
    attachments = scope / 'Screenshots'
    attachments.mkdir(parents=True, exist_ok=False)
    for row in chosen:
        row['attachments'] = [a for a in row['attachments'] if a.get('suggestedHumanReadableName', '').startswith(('ProductionScene-', 'ProductionMetadata-'))]
        for a in row['attachments']:
            original = (evidence / 'Screenshots' / a['exportedFileName']).resolve()
            if not original.is_relative_to((evidence / 'Screenshots').resolve()):
                raise ValueError('Original attachment path escapes evidence')
            shutil.copy2(original, attachments / a['exportedFileName'])
    (attachments / 'manifest.json').write_text(json.dumps(chosen))
    (scope / 'summary.json').write_text(json.dumps(dict(result='Passed', passedTests=len(selected), failedTests=0, skippedTests=0, expectedFailures=0,
        scope='individually verified passing photography cases only; original entire run remains Failed')))
    stage(scope / 'summary.json', attachments, output, source, 'iPad', run)
    report = output / 'OriginalReport'; report.mkdir()
    for name in ['summary.json', 'tests.json', 'ipad-device.json']:
        shutil.copy2(evidence / name, report / name)
    proof = dict(scope='individually executed passing original cases only', original_run_result='Failed', source=source, run=run,
                 selected_passed_tests=selected, excluded_failed_tests=[r['testIdentifierString'] for r in summary['testFailures']],
                 original_summary_sha256=hashlib.sha256((evidence / 'summary.json').read_bytes()).hexdigest())
    (output / 'scope.json').write_text(json.dumps(proof, indent=2)+'\n')
    return proof


def build(root, rows, output, scenes=None):
    scenes = scenes or SCENES
    expected = {(scene, mode, direction) for scene in scenes for mode in ['light', 'dark'] for direction in ['portrait', 'landscape']}
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
    page = '<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>طَيّة — صور iPad الأصلية</title><style>' + style + '</style><header><h1>طَيّة — صور الميزات على iPad</h1><p>' + str(len(records)) + ' صورة حقيقية · ' + str(len(scenes)) + ' شاشة × الفاتح والداكن × الطولي والعرضي. افتح أي صورة لحفظ PNG الأصلي كاملًا.</p><p>المصدر البرمجي: ' + APP_SOURCE + '</p></header><nav><select id="m"><option value="">كل الألوان</option><option value="light">فاتح</option><option value="dark">داكن</option></select><select id="d"><option value="">كل الاتجاهات</option><option value="portrait">طولي</option><option value="landscape">عرضي</option></select><input id="q" placeholder="اسم الميزة" aria-label="البحث عن ميزة"></nav><main>' + ''.join(cards) + '</main><script>' + script + '</script></html>'
    (output / 'index.html').write_text(page, encoding='utf-8')
    (output / 'features.json').write_text(json.dumps(records, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    (output / 'SHA256SUMS').write_text(''.join(r['sha256'] + '  ' + r['file'] + '\n' for r in records))
    (output / 'README.txt').write_text('صور حقيقية من تطبيق طَيّة الإنتاجي في وضع Debug على محاكي iPad Pro13، ببيانات عرض معزولة. لم تستخدم واجهات DesignStudio.\nافتح index.html للمعاينة أو Originals لملفات PNG الأصلية بلا إطارات أو قص أو تدوير أو إعادة تحجيم. قد يحتفظ PNG بوسم اتجاه EXIF أصلي؛ استخدم عارضًا يدعمه.\nالتسجيل يستخدم AVFoundation في المحاكي؛ الصور لا تثبت جودة الميكروفون على جهاز حقيقي. معاينة Office مصورة، ولا تدّعي اختبار تحويل Office على جهاز فعلي.\nلم يتغير كود التطبيق أو بيانات المستخدم أو Build15 المرفوع. التصوير منفصل عن اعتماد إصدار جديد.\n', encoding='utf-8')
    with (output / 'README.txt').open('a', encoding='utf-8') as note:
        note.write('تنبيه خاص بلقطات Office: معاينة محتوى المستند لم تكتمل في محاكي Quick Look؛ تظهر بعض الأصول حالة تحميل أو مساحة معاينة فارغة. هذه صور أصلية لحالة المحاكي، وليست إثباتًا لعرض أو تحويل Office كاملًا.\n')
    return records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for flag in ['captures', 'jobs', 'output']:
        parser.add_argument('--' + flag, type=Path, required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--run', type=int, required=True)
    parser.add_argument('--baseline-raw', type=Path)
    parser.add_argument('--baseline-jobs', type=Path)
    parser.add_argument('--baseline-source')
    parser.add_argument('--baseline-run', type=int)
    parser.add_argument('--core-only', action='store_true')
    args = parser.parse_args()
    jobs = json.loads(args.jobs.read_text())['jobs']
    groups = [('ipad-feature-', 'Native iPad', args.source, args.run, jobs)]
    if args.baseline_jobs:
        if not args.baseline_source or not args.baseline_run:
            raise ValueError('Immutable baseline source and run required')
        baseline = json.loads(args.baseline_jobs.read_text())['jobs']
        if not args.baseline_raw:
            raise ValueError('Preserved original failed reports and per-case proof are required')
        for mode in ['light', 'dark']:
            stage_baseline(args.baseline_raw, args.captures / ('ipad-feature-' + mode), args.baseline_source, args.baseline_run, mode)
        groups = [('ipad-feature-', 'Native iPad', args.baseline_source, args.baseline_run, baseline),
                  ('ipad-files-', 'Native iPad files', args.source, args.run, jobs)]
    rows = []
    for prefix, job_name, source, run, observed in groups:
        for mode in ['light', 'dark']:
            job = [j for j in observed if j['name'] == f'{job_name} ({mode})' and j['run_id'] == run and j['conclusion'] == ('failure' if args.baseline_jobs and prefix == 'ipad-feature-' else 'success')]
            if len(job) != 1:
                raise ValueError('Each color requires its own completed genuine native capture job')
            directory = prefix + mode
            root = args.captures / directory
            proof = json.loads((root / 'provenance.json').read_text())
            if proof != dict(source=source, family='iPad', run=run):
                raise ValueError('Actual capture provenance mismatch')
            for row in collect(root, source, 'iPad', run, job[0]['id']):
                if row['color_mode'] != mode:
                    raise ValueError('Actual launch appearance differs from requested job')
                row['file'] = directory + '/' + row['file']
                row['capture_test_result'] = 'Passed'
                row['original_run_result'] = 'Failed' if args.baseline_jobs and prefix == 'ipad-feature-' else 'Passed'
                row['verification_scope'] = 'individual native test; original failed run preserved' if row['original_run_result'] == 'Failed' else 'completed native photography job'
                rows.append(row)
    scenes = dict(list(SCENES.items())[:32]) if args.core_only else SCENES
    records = build(args.captures, rows, args.output, scenes=scenes)
    for mode in ['light', 'dark']:
        original = args.captures / ('ipad-feature-' + mode)
        if (original / 'OriginalReport').exists():
            shutil.copytree(original / 'OriginalReport', args.output / 'Provenance' / ('core-' + mode))
            shutil.copy2(original / 'scope.json', args.output / 'Provenance' / ('core-' + mode) / 'scope.json')
    (args.output / 'Provenance' / 'capture-scope.json').parent.mkdir(parents=True, exist_ok=True)
    (args.output / 'Provenance' / 'capture-scope.json').write_text(json.dumps(dict(
        application_source=APP_SOURCE, original_core_run=args.baseline_run, supplemental_run=args.run,
        reused_passed_original_cases=14 if args.baseline_jobs else None,
        superseded_failed_original_cases=6 if args.baseline_jobs else None,
        original_failed_reports_preserved=bool(args.baseline_jobs),
        original_png_bytes_modified=False, native_release_gate_rerun=False, renderer_source=os.environ.get('GITHUB_SHA')), indent=2)+'\n')
    archive = shutil.make_archive(str(args.output), 'zip', args.output.parent, args.output.name)
    print(json.dumps(dict(original_pngs=len(records), archive=archive, application_source=APP_SOURCE)))


if __name__ == '__main__':
    main()
