#!/usr/bin/env python3
"""Stage 6: build the extraction manifest and the updated inventory / unresolved-reference CSVs."""
import csv, hashlib, io, json, os, re, sys
from PIL import Image
OUT = sys.argv[1] if len(sys.argv) > 1 else '/mnt/user-data/outputs/part8'
OLD_INV = os.environ.get('BB2_OLD_INVENTORY', '/mnt/user-data/outputs/BB2_Asset_Audit_inventory.csv')
V2 = 'assets/extracted_v2'; os.makedirs(OUT, exist_ok=True)
def sha(b): return hashlib.sha256(b).hexdigest()
INTEGRATED = {
 'imagefont/high/blackframe/imagefont.png': 'integrated: battle damage/heal numbers (battle.gd via UI.image_text)',
 'imagefont/high/blackframe/glyphs.json': 'integrated: glyph rectangles for UI.image_text',
 'movie/opening_01.ogv': 'integrated: opening intro (opening.gd), New Game + More > Watch Opening',
 'movie/opening_02.ogv': 'integrated: opening intro (opening.gd), plays after opening_01',
}
rows = []
def add(path, kind, source, data=None, note='', integ=None):
    fp = os.path.join(V2, path) if not path.startswith('data/') else path
    b = open(fp, 'rb').read(); w = h = mode = ''; fmt = path.rsplit('.', 1)[-1].upper()
    if path.endswith('.png'):
        im = Image.open(io.BytesIO(b)); w, h, mode = im.width, im.height, im.mode
    rows.append({'file': ('assets/extracted_v2/' + path) if not path.startswith('data/') else path, 'kind': kind, 'source': source, 'format': fmt, 'width': w, 'height': h, 'color_mode': mode,
                 'bytes': len(b), 'sha256': sha(b), 'integration_status': integ or INTEGRATED.get(path) or 'available, not integrated (no verified usage mapped yet)', 'note': note})
s1 = {r['path']: r for r in csv.DictReader(open(f'{V2}/manifest_stage1.csv'))}
for p, r in s1.items():
    kind = r['kind']
    src = f"APK {r['source_apk']}: {r['source_entry'].replace('assets/bootstrap/d05b587e7822384331c8a384f96541e6/', '@/')}" if r['source_entry'] else f"derived from APK {r['source_apk']}"
    add(p, kind, src, note=r['note'])
for root, _, fs in os.walk(f'{V2}/imagefont'):
    for f in sorted(fs):
        rel = os.path.relpath(os.path.join(root, f), V2).replace(os.sep, '/')
        if rel in s1: continue
        lod, style = rel.split('/')[1:3]
        add(rel, 'imagefont_derived', f'derived from imagefont/{lod}/{style}/imagefont.png + imagefont.json (APK B)', note='glyph crop / BMFont descriptor / glyph table (coordinates rescaled from JSON space to PNG space)')
for n in ('opening_01', 'opening_02'):
    r = [x for x in csv.DictReader(open(f'{V2}/manifest_stage3.csv')) if x['path'] == f'movie/{n}.ogv'][0]
    add(f'movie/{n}.ogv', 'video_converted', f"APK A=B: …/Content/lang/audio/movie/{n}.mp4", note=r['note'])
    rows[-1]['width'], rows[-1]['height'], rows[-1]['color_mode'] = 320, 480, 'yuv420p'
idx = json.load(open('data/original_extract/_index.json'))
for kind, key in (('layout', 'layouts'), ('animation', 'animations')):
    for e in idx[key]:
        b = open('data/original_extract/' + e['file'], 'rb').read()
        rows.append({'file': 'data/original_extract/' + e['file'], 'kind': f'{kind}_json', 'source': 'APK B application.js (XOR 0x55, decoded in memory): exports.' + ('lbViewJSON' if kind == 'layout' else 'ABJSON'),
                     'format': 'JSON', 'width': '', 'height': '', 'color_mode': '', 'bytes': len(b), 'sha256': sha(b), 'integration_status': 'available, not integrated (layouts/animations are data; screens are still hand-built)',
                     'note': (e.get('kind', '') + ' ' if kind == 'animation' else '') + f"image refs {e['distinct_image_refs']}: {e['ref_classes']}"})
for p in ('_index.json', '_layout_schema.json', 'reference_trace.csv'):
    b = open('data/original_extract/' + p, 'rb').read()
    rows.append({'file': 'data/original_extract/' + p, 'kind': 'analysis_output', 'source': 'derived by tools/part8', 'format': p.rsplit('.', 1)[-1].upper(), 'width': '', 'height': '', 'color_mode': '', 'bytes': len(b), 'sha256': sha(b), 'integration_status': 'documentation/analysis', 'note': ''})
with open(f'{OUT}/BB2_Part8_extraction_manifest.csv', 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
# ---- updated inventory
inv = list(csv.DictReader(open(OLD_INV)))
bs = 'assets/bootstrap/d05b587e7822384331c8a384f96541e6/'
extra = {'common/world/sheet02.png'}                                   # contains worldmap.png (used as zone-select backdrop)
n_upd = 0
for r in inv:
    r['part8_update'] = ''; r['extracted_v2_path'] = ''; r['integration_note'] = ''
    p = r['path']
    if p.startswith(bs + 'Content/lang/images/'):
        rel = p[len(bs + 'Content/lang/images/'):]
        if r['project_status'].startswith(('NOT extracted', 'partially extracted')):
            tgt = f'images/{rel}'
            if os.path.exists(f'{V2}/{tgt}'): r['part8_update'] = 'extracted byte-exact (Part 8)'; r['extracted_v2_path'] = 'assets/extracted_v2/' + tgt; n_upd += 1
        if rel in extra: r['used_in_godot'] = 'yes'; r['integration_note'] = 'worldmap.png sprite used as Adventure zone-select backdrop (layout RegionSelect)'
    elif '/imagefont/' in p:
        part = p.split('Content/lang/imagefont/')[1]; lod, style, fn = part.split('/')
        if os.path.exists(f'{V2}/imagefont/{lod}/{style}/{fn}'): r['part8_update'] = 'extracted (Part 8) + glyphs mapped'; r['extracted_v2_path'] = f'assets/extracted_v2/imagefont/{lod}/{style}/{fn}'; n_upd += 1
        if lod == 'high' and style == 'blackframe': r['used_in_godot'] = 'yes'; r['integration_note'] = 'battle damage/heal numbers'
    elif p.endswith('.mp4'):
        n = os.path.basename(p)[:-4]; r['part8_update'] = 'converted to Ogg Theora (Part 8)'; r['extracted_v2_path'] = f'assets/extracted_v2/movie/{n}.ogv'; r['used_in_godot'] = 'yes'; r['integration_note'] = 'opening intro'; n_upd += 1
    elif p == bs + 'application.js':
        r['part8_update'] = 'layout/animation tables exported to data/original_extract (decoded in memory only)'; n_upd += 1
fields = list(inv[0].keys())
with open(f'{OUT}/BB2_Asset_Audit_inventory_v2.csv', 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=fields); w.writeheader(); w.writerows(inv)
tr = list(csv.DictReader(open('data/original_extract/reference_trace.csv')))
with open(f'{OUT}/BB2_Asset_Audit_unresolved_refs_v2.csv', 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=list(tr[0].keys())); w.writeheader(); w.writerows(tr)
import collections
print('manifest rows:', len(rows), dict(collections.Counter(r['kind'] for r in rows)))
print('inventory rows updated:', n_upd, '| refs rows:', len(tr), dict(collections.Counter(r['classification'] for r in tr)))
print('integration status:', dict(collections.Counter(r['integration_status'].split(':')[0] for r in rows)))
