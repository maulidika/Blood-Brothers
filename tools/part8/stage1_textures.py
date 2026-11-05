#!/usr/bin/env python3
"""Stage 1: byte-exact extraction of textures not covered by textureJSON, the 4 uncovered sheets, and imagefont."""
import csv, io, json, os, sys, urllib.parse
import numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0, os.path.dirname(__file__)); from common import *
OUT = sys.argv[1] if len(sys.argv) > 1 else 'assets/extracted_v2'
os.makedirs(OUT, exist_ok=True)
manifest = []
def rec(kind, rel, ver, data, note=''):
    im = Image.open(io.BytesIO(data)) if rel.endswith('.png') else None
    manifest.append({'kind': kind, 'path': rel, 'source_apk': ver, 'source_entry': '', 'format': 'PNG' if im else rel.rsplit('.', 1)[-1],
        'width': im.width if im else '', 'height': im.height if im else '', 'mode': im.mode if im else '',
        'has_alpha': ('A' in im.mode or 'transparency' in im.info) if im else '', 'bytes': len(data), 'sha256': sha(data), 'note': note})

# ---- which sheets does the sprite table cover? (per version)
def best_tex(ver):
    return exported_table(ver, 'textureJSON') or {}
covered = {}
for v in 'AB':
    tex = best_tex(v); s = set()
    for d, sp in tex.items():
        for n, m in sp.items(): s.add(f"{d}/{m['src']}")
    covered[v] = s
SPECIAL = {'common/signup/sheet03.png', 'common/ui/header/sheet01.png', 'common/ui/dialog/sheet01.png', 'common/login/sheet03.png'}
# ---- 1) standalone textures: PNG in APK, not a table sheet. Newer (B) bytes preferred, A-only kept.
imgs = {v: images(v) for v in 'AB'}
rels = sorted(set(imgs['A']) | set(imgs['B']))
n_std = 0
for rel in rels:
    ver = 'B' if rel in imgs['B'] else 'A'
    base_rel = rel.replace('_low.png', '.png') if rel.endswith('_low.png') else rel
    in_table = base_rel in covered['A'] or base_rel in covered['B']      # a _low file belongs to its hi sheet
    if in_table or base_rel in SPECIAL: continue
    data = apk(ver).read(imgs[ver][rel])
    dst = os.path.join(OUT, 'images', rel); os.makedirs(os.path.dirname(dst), exist_ok=True); open(dst, 'wb').write(data)
    same = (rel in imgs['A'] and rel in imgs['B'] and apk('A').read(imgs['A'][rel]) == apk('B').read(imgs['B'][rel]))
    rec('standalone_texture', 'images/' + rel, ver, data, 'identical in A and B' if same else f'present in {"A and B (differs)" if rel in imgs["A"] and rel in imgs["B"] else ver+" only"}')
    manifest[-1]['source_entry'] = imgs[ver][rel]
    if not rel.endswith('_low.png'): n_std += 1
print('standalone textures (non-low):', n_std, '| files incl _low:', sum(1 for m in manifest if m['kind'] == 'standalone_texture'))

# ---- 2) the 4 special sheets: raw copy + analysis of regions not covered by the table
reg_index = {}
for rel in sorted(SPECIAL):
    for low in ('', '_low'):
        r = rel.replace('.png', low + '.png')
        ver = 'B' if r in imgs['B'] else ('A' if r in imgs['A'] else None)
        if not ver: continue
        data = apk(ver).read(imgs[ver][r]); dst = os.path.join(OUT, 'images', r); os.makedirs(os.path.dirname(dst), exist_ok=True); open(dst, 'wb').write(data)
        rec('uncovered_sheet', 'images/' + r, ver, data, 'whole sheet, byte-exact'); manifest[-1]['source_entry'] = imgs[ver][r]
    ver = 'B' if rel in imgs['B'] else 'A'
    im = Image.open(io.BytesIO(apk(ver).read(imgs[ver][rel]))).convert('RGBA'); a = np.array(im)[:, :, 3] > 8
    cover = np.zeros_like(a); tex = best_tex(ver); d, name = rel.rsplit('/', 1)
    for nm, m in tex.get(d, {}).items():
        if m['src'] != name: continue
        u, v_, w, h = m['uv']; W, H = im.size
        cover[max(0, int(v_ * H) - 1):int((v_ + h) * H) + 2, max(0, int(u * W) - 1):int((u + w) * W) + 2] = True
    unc = a & ~cover
    lab, n = ndimage.label(ndimage.binary_dilation(unc, iterations=3) & a)
    regions = []
    for i, sl in enumerate(ndimage.find_objects(lab), 1):
        ys, xs = sl; area = int((lab[sl] == i).sum())
        if area < 100: continue
        regions.append({'id': len(regions), 'x': xs.start, 'y': ys.start, 'w': xs.stop - xs.start, 'h': ys.stop - ys.start, 'opaque_px': area})
    if rel.endswith('sheet03.png') and 'signup' in rel or rel == 'common/ui/header/sheet01.png':
        regions = [{'id': 0, 'x': 0, 'y': 0, 'w': im.width, 'h': im.height, 'opaque_px': int(a.sum()), 'note': 'sheet has no sprites in table; whole image is the asset'}]
    od = os.path.join(OUT, 'regions', rel.replace('.png', '')); os.makedirs(od, exist_ok=True)
    for rg in regions:
        crop = im.crop((rg['x'], rg['y'], rg['x'] + rg['w'], rg['y'] + rg['h'])); buf = io.BytesIO(); crop.save(buf, 'PNG')
        open(os.path.join(od, f"region_{rg['id']:02d}.png"), 'wb').write(buf.getvalue())
        manifest.append({'kind': 'derived_region', 'path': f"regions/{rel.replace('.png','')}/region_{rg['id']:02d}.png", 'source_apk': ver, 'source_entry': imgs[ver][rel],
            'format': 'PNG', 'width': rg['w'], 'height': rg['h'], 'mode': 'RGBA', 'has_alpha': True, 'bytes': len(buf.getvalue()), 'sha256': sha(buf.getvalue()),
            'note': f"derived crop at ({rg['x']},{rg['y']}) of {rel}; NOT an original file; name assigned by us"})
    reg_index[rel] = {'sheet_size': list(im.size), 'table_sprites_in_sheet': sum(1 for m in tex.get(d, {}).values() if m['src'] == name), 'regions': regions}
json.dump(reg_index, open(os.path.join(OUT, 'regions', 'regions.json'), 'w'), indent=1)
print('special sheets:', {k: len(v['regions']) for k, v in reg_index.items()})

# ---- 3) imagefont: raw png/json, per-glyph crops, BMFont .fnt for Godot
for lod in ('high', 'low'):
    for style in ('blackframe', 'cutin', 'white'):
        base = f'Content/lang/imagefont/{lod}/{style}/'
        ver = 'B'
        png = apk(ver).read(bootstrap(ver) + base + 'imagefont.png'); js = apk(ver).read(bootstrap(ver) + base + 'imagefont.json')
        od = os.path.join(OUT, 'imagefont', lod, style); os.makedirs(os.path.join(od, 'glyphs'), exist_ok=True)
        open(os.path.join(od, 'imagefont.png'), 'wb').write(png); open(os.path.join(od, 'imagefont.json'), 'wb').write(js)
        rec('imagefont_atlas', f'imagefont/{lod}/{style}/imagefont.png', ver, png); manifest[-1]['source_entry'] = bootstrap(ver) + base + 'imagefont.png'
        rec('imagefont_json', f'imagefont/{lod}/{style}/imagefont.json', ver, js); manifest[-1]['source_entry'] = bootstrap(ver) + base + 'imagefont.json'
        j = json.loads(js); im = Image.open(io.BytesIO(png)).convert('RGBA')
        sc = im.width / float(j['meta']['size']['w'])        # JSON coordinates are in meta.size space; PNG may be smaller
        chars = []; fnt = []
        for k, fr in j['frames'].items():
            ch = urllib.parse.unquote(k[:-4]); f = fr['frame']
            if len(ch) != 1: continue
            x, y, w, h = (round(f['x'] * sc), round(f['y'] * sc), max(1, round(f['w'] * sc)), max(1, round(f['h'] * sc)))
            im.crop((x, y, x + w, y + h)).save(os.path.join(od, 'glyphs', f'u{ord(ch):04x}.png'))
            chars.append({'char': ch, 'code': ord(ch), 'x': x, 'y': y, 'w': w, 'h': h, 'json_rect': [f['x'], f['y'], f['w'], f['h']],
                          'rotated': fr['rotated'], 'trimmed': fr['trimmed']})
        chars.sort(key=lambda c: c['code'])
        lh = max(c['h'] for c in chars)
        fnt.append(f'info face="BB2 imagefont {lod}/{style}" size={lh} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=0,0')
        fnt.append(f'common lineHeight={lh} base={lh} scaleW={im.width} scaleH={im.height} pages=1 packed=0')
        fnt.append('page id=0 file="imagefont.png"'); fnt.append(f'chars count={len(chars)}')
        for c in chars:
            fnt.append(f"char id={c['code']} x={c['x']} y={c['y']} width={c['w']} height={c['h']} xoffset=0 yoffset=0 xadvance={c['w']} page=0 chnl=15")
        open(os.path.join(od, 'imagefont.fnt'), 'w').write('\n'.join(fnt) + '\n')
        json.dump({'png_size': list(im.size), 'json_space': j['meta']['size'], 'scale_json_to_png': sc, 'line_height': lh, 'glyphs': chars, 'meta': j['meta']},
                  open(os.path.join(od, 'glyphs.json'), 'w'), indent=1, ensure_ascii=False)
        print(f'imagefont {lod}/{style}: {len(chars)} glyphs, png {im.size}, scale {sc}, charset: {"".join(c["char"] for c in chars)}')
with open(os.path.join(OUT, 'manifest_stage1.csv'), 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=list(manifest[0].keys())); w.writeheader(); w.writerows(manifest)
print('manifest rows:', len(manifest))
