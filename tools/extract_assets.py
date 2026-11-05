#!/usr/bin/env python3
"""
Blood Brothers 2 asset extractor (read-only on the original APKs).

Usage:
  python3 tools/extract_assets.py <apk_or_zip_A> <apk_or_zip_B> [--out assets/original]

Order matters: pass the OLDER build first (2.5.2.9.2) then the NEWER (2.5.3.1.0).
Newer files override older ones; files that exist only in the older build are kept.

What it does
  * opens the APK/ZIP in memory/temp dir (originals are never modified)
  * undoes the single-byte XOR packaging of application.js (key 0x55) ONLY to read
    the sprite-sheet table (textureJSON) so the atlas can be sliced back into sprites
  * slices every atlas sheet into individual PNG sprites  -> <out>/ui/<dir>/<name>.png
  * converts .m4a BGM to .ogg (Godot cannot import m4a)     -> <out>/audio/bgm/*.ogg
  * copies .ogg SFX, fonts, opening videos, localisation text
  * writes <out>/atlas_index.json (sprite -> source sheet + pixel rect)
Requires: Pillow, ffmpeg (with libvorbis).
"""
import argparse, glob, json, os, shutil, subprocess, sys, tempfile, zipfile
from PIL import Image

XOR_KEY = 0x55

def open_pkg(path, tmp):
    """Return directory containing the unpacked APK (handles zip-wrapping-apk)."""
    d = os.path.join(tmp, os.path.basename(path) + '_x')
    os.makedirs(d, exist_ok=True)
    with zipfile.ZipFile(path) as z:
        z.extractall(d)
    inner = [f for f in glob.glob(os.path.join(d, '*.apk'))]
    if inner:
        d2 = d + '_apk'
        os.makedirs(d2, exist_ok=True)
        with zipfile.ZipFile(inner[0]) as z:
            z.extractall(d2)
        return d2
    return d

def bootstrap(root):
    g = glob.glob(os.path.join(root, 'assets', 'bootstrap', '*'))
    if not g:
        sys.exit('bootstrap folder not found in ' + root)
    return g[0]

def read_texture_json(bs):
    raw = open(os.path.join(bs, 'application.js'), 'rb').read()
    txt = bytes(b ^ XOR_KEY for b in raw).decode('utf-8', 'replace')
    best, pos = {}, 0
    while True:                                   # some builds define it twice (first one empty)
        i = txt.find('exports.textureJSON', pos)
        if i < 0:
            break
        pos = i + 1
        j = txt.find('{', i)
        try:
            obj, _ = json.JSONDecoder().raw_decode(txt[j:])
        except ValueError:
            continue
        if len(obj) > len(best):
            best = obj
    return best

def slice_sheets(bs, out, index):
    tex = read_texture_json(bs)
    img_root = os.path.join(bs, 'Content', 'lang', 'images')
    n = 0
    for dirkey, sprites in tex.items():
        if '[DOWNLOAD_CONTENT]' in dirkey or dirkey.startswith('DownloadContent'):
            continue                              # downloaded from server in 2015; not in the APK
        cache = {}
        for name, meta in sprites.items():
            sheet = os.path.join(img_root, dirkey, meta['src'])
            if not os.path.exists(sheet):
                continue
            if sheet not in cache:
                cache[sheet] = Image.open(sheet).convert('RGBA')
            im = cache[sheet]
            u, v, w, h = meta['uv']
            x, y = round(u * im.width), round(v * im.height)
            ww, hh = max(1, round(w * im.width)), max(1, round(h * im.height))
            dest = os.path.join(out, 'ui', dirkey, name)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            im.crop((x, y, x + ww, y + hh)).save(dest)
            index[dirkey + '/' + name] = {'sheet': dirkey + '/' + meta['src'], 'rect': [x, y, ww, hh]}
            n += 1
    return n

def convert_audio(bs, out):
    n = 0
    for p in glob.glob(os.path.join(bs, 'Content', '**', '*.m4a'), recursive=True):
        rel = os.path.relpath(p, os.path.join(bs, 'Content'))
        dest = os.path.join(out, 'audio', os.path.splitext(rel)[0] + '.ogg')
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        r = subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', p, '-c:a', 'libvorbis', '-q:a', '4', dest])
        n += (r.returncode == 0)
    for p in glob.glob(os.path.join(bs, 'Content', '**', '*.ogg'), recursive=True):
        rel = os.path.relpath(p, os.path.join(bs, 'Content'))
        dest = os.path.join(out, 'audio', rel)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copy2(p, dest); n += 1
    return n

def copy_misc(bs, out):
    for p in glob.glob(os.path.join(bs, 'Content', '**', '*.ttf'), recursive=True):
        os.makedirs(os.path.join(out, 'font'), exist_ok=True); shutil.copy2(p, os.path.join(out, 'font'))
    for p in glob.glob(os.path.join(bs, 'Content', '**', '*.mp4'), recursive=True):
        os.makedirs(os.path.join(out, 'movie'), exist_ok=True); shutil.copy2(p, os.path.join(out, 'movie'))
    t = os.path.join(bs, 'DownloadContent', 'lang', 'text', 'system.json')
    if os.path.exists(t):
        os.makedirs(os.path.join(out, 'text'), exist_ok=True); shutil.copy2(t, os.path.join(out, 'text'))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('older'); ap.add_argument('newer')
    ap.add_argument('--out', default='assets/original')
    a = ap.parse_args()
    index = {}
    with tempfile.TemporaryDirectory() as tmp:
        for label, pkg in (('older', a.older), ('newer', a.newer)):
            root = open_pkg(pkg, tmp); bs = bootstrap(root)
            ns = slice_sheets(bs, a.out, index)
            na = convert_audio(bs, a.out)
            copy_misc(bs, a.out)
            print(f'[{label}] {os.path.basename(pkg)}: {ns} sprites, {na} audio files')
    json.dump(index, open(os.path.join(a.out, 'atlas_index.json'), 'w'), indent=0)
    print('total unique sprites:', len(index))

if __name__ == '__main__':
    main()
