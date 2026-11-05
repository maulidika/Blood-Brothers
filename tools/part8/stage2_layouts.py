#!/usr/bin/env python3
"""Stage 2: export lbViewJSON (UI layouts) and ABJSON (AnimationBuilder animations) from application.js (decoded IN MEMORY)."""
import collections, csv, hashlib, json, os, re, sys
sys.path.insert(0, os.path.dirname(__file__)); from common import *
OUT = sys.argv[1] if len(sys.argv) > 1 else 'data/original_extract'
V2 = sys.argv[2] if len(sys.argv) > 2 else 'assets/extracted_v2'
lb = exported_table('B', 'lbViewJSON'); ab = exported_table('B', 'ABJSON')
lbA = exported_table('A', 'lbViewJSON') or {}; abA = exported_table('A', 'ABJSON') or {}
tex = exported_table('B', 'textureJSON')
sprite_keys = set(f'{d}/{n}' for d, s in tex.items() for n in s)
imgs_B = set(images('B')); standalone_v2 = set()
for root, _, fs in os.walk(os.path.join(V2, 'images')):
    for f in fs: standalone_v2.add(os.path.relpath(os.path.join(root, f), os.path.join(V2, 'images')).replace(os.sep, '/'))

def leaves_png(o, acc):
    if isinstance(o, dict):
        for k, v in o.items(): leaves_png(v, acc)
    elif isinstance(o, list):
        for v in o: leaves_png(v, acc)
    elif isinstance(o, str) and o.lower().endswith('.png'): acc.append(o)
def classify(ref):
    if 'DOWNLOAD_CONTENT' in ref or ref.startswith('DownloadContent'): return 'server_download_marker'
    if ref in sprite_keys: return 'sprite_table_exact'
    if ref in imgs_B or ref in standalone_v2: return 'standalone_file_in_apk'
    return 'unresolved'
def count_nodes(n, c):
    if isinstance(n, dict):
        if 'type' in n and 'attrs' in n: c[n['type']] += 1
        for v in n.values(): count_nodes(v, c)
    elif isinstance(n, list):
        for v in n: count_nodes(v, c)
def dump(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    s = json.dumps(obj, indent=1, ensure_ascii=False); open(path, 'w', encoding='utf-8').write(s); return s
index = {'layouts': [], 'animations': [], 'notes': {}}
unres = collections.defaultdict(list); tot = collections.Counter()
for kind, tbl, folder in (('layout', lb, 'layouts'), ('animation', ab, 'animations')):
    for name in sorted(tbl):
        assert '..' not in name and not name.startswith('/')
        rel = f'{folder}/{name}.json'; s = dump(os.path.join(OUT, rel), tbl[name])
        assert json.load(open(os.path.join(OUT, rel), encoding='utf-8')) == tbl[name]       # lossless round-trip
        refs = []; leaves_png(tbl[name], refs); nodes = collections.Counter(); count_nodes(tbl[name], nodes)
        cl = collections.Counter(classify(r) for r in set(refs))
        for r in set(refs):
            c = classify(r); tot[c] += 1
            if c == 'unresolved': unres[r].append(name)
        e = {'name': name, 'file': rel, 'bytes': len(s.encode()), 'sha256': hashlib.sha256(s.encode()).hexdigest(), 'distinct_image_refs': len(set(refs)),
             'ref_classes': dict(cl), 'node_types': dict(nodes)}
        if kind == 'animation':
            a = tbl[name]; e.update({'fps': a.get('fps'), 'screen': a.get('screenSize'), 'runtime': (a.get('meta') or {}).get('runtime_type'), 'kind': 'download_list' if name == 'Downloadables' else 'animation'})
        else:
            e['in_A_2_5_2_9_2'] = name in lbA; e['identical_in_A'] = (lbA.get(name) == tbl[name]) if name in lbA else None
        index['layouts' if kind == 'layout' else 'animations'].append(e)
index['notes'] = {'source_apk': 'B (2.5.3.1.0)', 'A_embedded_layouts': len(lbA), 'A_embedded_animations': len(abA),
    'ref_totals_distinct_per_file': dict(tot), 'unresolved_refs': {k: v for k, v in sorted(unres.items())}}
dump(os.path.join(OUT, '_index.json'), index)
# schema summary
attr = collections.Counter(); types = collections.Counter()
def walk(n):
    if isinstance(n, dict):
        if 'type' in n and 'attrs' in n:
            types[n['type']] += 1
            for k in n['attrs']: attr[k] += 1
        for v in n.values(): walk(v)
    elif isinstance(n, list):
        for v in n: walk(v)
walk(lb)
dump(os.path.join(OUT, '_layout_schema.json'), {'node_types': dict(types), 'attr_keys': dict(attr.most_common())})
print('layouts', len(index['layouts']), 'animations', len(index['animations']), '| A embeds', len(lbA), 'layouts /', len(abA), 'animations')
print('node types:', dict(types)); print('image-ref classes (distinct per file):', dict(tot)); print('distinct unresolved refs:', len(unres))
