"""Shared helpers for Part 8 extraction. READ-ONLY on the original APKs/zips."""
import io, json, zipfile, hashlib, re, os
UPLOADS = os.environ.get('BB2_UPLOADS', '/mnt/user-data/uploads')     # folder holding the two original ZIP/APK files
PKGS = {'A': (f'{UPLOADS}/Blood_Brothers-2_5_2_9_2.zip', 'Blood_Brothers-2.5.2.9.2.apk'),
        'B': (f'{UPLOADS}/blood-brothers-2-5-3-1-0.zip', 'blood-brothers-2-5-3-1-0.apk')}
XOR_KEY = 0x55
_cache = {}

def apk(ver):
    if ver not in _cache:
        z, n = PKGS[ver]
        _cache[ver] = zipfile.ZipFile(io.BytesIO(zipfile.ZipFile(z).read(n)))
    return _cache[ver]

def bootstrap(ver):
    for n in apk(ver).namelist():
        m = re.match(r'(assets/bootstrap/[0-9a-f]+/)', n)
        if m: return m.group(1)

def read(ver, rel):               # rel is relative to bootstrap/
    return apk(ver).read(bootstrap(ver) + rel)

def sha(b): return hashlib.sha256(b).hexdigest()

def js_text(ver):                 # decoded in memory only; original file untouched
    if ('js', ver) not in _cache:
        raw = read(ver, 'application.js')
        _cache[('js', ver)] = bytes(b ^ XOR_KEY for b in raw).decode('utf-8', 'replace')
    return _cache[('js', ver)]

def exported_table(ver, name):
    """Largest successfully parsed `exports.<name> = {...}|[...]` literal."""
    txt = js_text(ver); dec = json.JSONDecoder(); best = None
    for m in re.finditer(r'exports\.%s\s*=\s*([\{\[])' % re.escape(name), txt):
        try: o, e = dec.raw_decode(txt[m.end() - 1:])
        except Exception: continue
        if best is None or e > best[1]: best = (o, e)
    return best[0] if best else None

def images(ver):
    base = bootstrap(ver) + 'Content/lang/images/'
    return {n[len(base):]: n for n in apk(ver).namelist() if n.startswith(base) and n.endswith('.png')}
