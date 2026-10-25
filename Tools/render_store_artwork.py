"""Typeset Tayya-branded App Store art around byte-preserved real screenshots."""
import argparse
import hashlib
import html
import json
import shutil
import threading
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from PIL import Image
from playwright.sync_api import sync_playwright

BRAND = Path(__file__).resolve().parents[1] / 'Store' / 'Studio2'
FOLD = 'M.08 .12H.78Q.85 .12 .87 .21L.91 .34Q.94 .39 .85 .43L.61 .59Q.58 .61 .58 .65V.95L.42 .86Q.35 .83 .35 .76V.51Q.35 .47 .40 .45L.65 .31H.25Q.17 .31 .13 .23Z'


def render(root: Path, captures: Path, output: Path, family: str, width: int, height: int):
    allowed = {'iPhone': {(1206, 2622), (1320, 2868)}, 'iPad': {(2064, 2752)}}
    if (width, height) not in allowed[family]:
        raise ValueError('Use an explicitly supported App Store portrait size')
    rows = json.loads(captures.read_text())
    rows = [r.get('after', r) for r in rows]
    output.mkdir(parents=True, exist_ok=False)
    (output / 'originals').mkdir()
    shutil.copytree(BRAND / 'fonts', output / 'fonts')
    shutil.copy2(BRAND / 'artwork.css', output / 'artwork.css')
    result = []
    class QuietHandler(SimpleHTTPRequestHandler):
        def log_message(self, *_):
            pass
    server = ThreadingHTTPServer(('127.0.0.1', 0), partial(QuietHandler, directory=str(output.resolve())))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    with sync_playwright() as p:
        executable = shutil.which('chromium') or shutil.which('google-chrome')
        if not executable:
            raise RuntimeError('Use an existing Chromium/Chrome browser; do not silently install another renderer')
        browser = p.chromium.launch(executable_path=executable, args=['--no-sandbox'])
        page = browser.new_page(viewport={'width': width, 'height': height}, device_scale_factor=1)
        for story in json.loads((BRAND / 'copy-ar.json').read_text()):
            scene = story.get('ipad_scene', story['scene']) if family == 'iPad' else story['scene']
            color = story.get('ipad_color', 'light') if family == 'iPad' else 'light'
            candidates = [r for r in rows if r['family'] == family and r.get('screen', r.get('scene')) == scene
                          and r.get('language') == 'ar' and r.get('font_size') == 'default'
                          and r.get('color_mode') == color and r.get('orientation') == 'portrait']
            if len(candidates) != 1:
                raise ValueError(f'Expected one real {family}/{scene}/{color} capture, found {len(candidates)}')
            row = candidates[0]
            source = (root / row['file']).resolve()
            if not source.is_relative_to(root.resolve()) or not source.is_file():
                raise ValueError('The real screenshot must be within the declared capture root')
            raw = source.read_bytes()
            digest = hashlib.sha256(raw).hexdigest()
            if digest != row['sha256']:
                raise ValueError('Raw screenshot hash no longer matches native evidence')
            if family == 'iPhone' and (row['pixel_width'], row['pixel_height']) != (width, height):
                raise ValueError('Do not relabel a different actual phone capture size')
            if family == 'iPad' and (row['pixel_width'], row['pixel_height']) != (2064, 2752):
                raise ValueError('The native iPad screenshot must be from the 13-inch display')
            original = 'originals/' + story['id'] + '.png'
            (output / original).write_bytes(raw)
            aspect = row['window_width'] / row['window_height']
            screen_height = height * .747
            screen_width = screen_height * aspect
            heading = story.get('ipad_heading', story['heading']) if family == 'iPad' else story['heading']
            lines = ''.join('<span>' + html.escape(line) + '</span>' for line in heading)
            markup = f'''<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8">
<title>{html.escape(story['label'])} — طَيّة</title><link rel="stylesheet" href="artwork.css">
<body class="{story['theme']} {'tablet' if family == 'iPad' else 'phone'}" style="--w:{width}px;--h:{height}px;--screen-w:{screen_width}px;--screen-h:{screen_height}px">
<div class="fold-edge"></div><div class="fold-stitch"></div>
<div class="brand"><svg viewBox="0 0 1 1" aria-hidden="true"><path d="{FOLD}"/></svg><span class="brand-name">طَيّة</span><span class="brand-latin">TAYYA</span></div>
<div class="eyebrow"><span>{html.escape(story['label'])}</span></div>
<h1 class="headline">{lines}</h1><p class="detail">{html.escape(story['detail'])}</p>
<div class="app-frame"><img src="{original}" alt="{html.escape(scene)} — لقطة فعلية من التطبيق"></div>
</body></html>'''
            document = output / (story['id'] + '.html')
            document.write_text(markup)
            page.goto(f'http://127.0.0.1:{server.server_port}/' + document.name, wait_until='load')
            page.evaluate('document.fonts.ready')
            page.locator('.app-frame img').evaluate('(img) => img.decode()')
            geometry = page.evaluate('''() => {
              const b=s=>{let r=document.querySelector(s).getBoundingClientRect();return {top:r.top,bottom:r.bottom,left:r.left,right:r.right}};
              return {headline:b('.headline'),detail:b('.detail'),frame:b('.app-frame'),
                noWordOverflow:[...document.querySelectorAll('.headline span')].every(e=>e.scrollWidth<=e.clientWidth),
                fontReady:document.fonts.check('700 40px TayyaHeadline')};}''')
            if not geometry['fontReady'] or not geometry['noWordOverflow']:
                raise ValueError('Arabic font or title bounds failed: ' + story['id'])
            if not (geometry['headline']['bottom'] < geometry['detail']['top']
                    and geometry['detail']['bottom'] < geometry['frame']['top']
                    and geometry['frame']['bottom'] <= height):
                raise ValueError('Text/image overlap or out-of-canvas frame: ' + story['id'])
            png = output / (story['id'] + '.png')
            page.screenshot(path=str(png), full_page=False, omit_background=False)
            with Image.open(png) as image:
                if image.mode != 'RGB':
                    # Encoding normalization only; the original app PNG remains byte-identical.
                    image.convert('RGB').save(png)
            result.append({'file': png.name, 'editable': document.name, 'family': family, 'locale': 'ar-SA',
                           'width': width, 'height': height, 'mode': 'RGB', 'source_capture': row,
                           'original_file': original, 'original_sha256': digest,
                           'sha256': hashlib.sha256(png.read_bytes()).hexdigest(), 'geometry': geometry})
        browser.close()
    server.shutdown()
    server.server_close()
    (output / 'store-artwork.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    cards = ''.join(f'<a href="{r["editable"]}"><img src="{r["file"]}" alt="طَيّة — {r["file"]}"></a>' for r in result)
    (output / 'index.html').write_text('<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>صور متجر طَيّة</title><style>body{margin:24px;background:#F8F7F3;color:#244C43;font:18px system-ui}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:20px}img{width:100%;border-radius:12px}</style><h1>طَيّة — صور المتجر</h1><p>تصميم تسويقي حول لقطات فعلية؛ الأصول وبيانات المصدر محفوظة.</p><main>' + cards + '</main></html>')
    print(json.dumps({'family': family, 'size': [width, height], 'images': len(result), 'output': str(output)}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--captures', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--family', choices=['iPhone', 'iPad'], required=True)
    parser.add_argument('--width', type=int, required=True)
    parser.add_argument('--height', type=int, required=True)
    args = parser.parse_args()
    render(args.root, args.captures, args.output, args.family, args.width, args.height)
