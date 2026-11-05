#!/usr/bin/env python3
"""Stage 4: trace every PNG reference not matched by the sprite table / APK files (A and B), using the client's own path rules."""
import collections, csv, json, os, re, sys
sys.path.insert(0, os.path.dirname(__file__)); from common import *
OUT = sys.argv[1] if len(sys.argv) > 1 else 'data/original_extract/reference_trace.csv'
V2 = 'assets/extracted_v2'; PRJ = 'assets/original'
ref_all = json.load(open('data/original_extract/_audit_refs_class2.json'))           # audit result (A='xa', B='xb')
idx = json.load(open('data/original_extract/_index.json'))
seed = {}
for v, k in (('B', 'xb'), ('A', 'xa')):
    for r in ref_all[k].get('E_unresolved', []): seed.setdefault(r, set()).add(f'audit_E_{v}')
for r, names in idx['notes']['unresolved_refs'].items(): seed.setdefault(r, set()).add('layout_or_animation_ref')
print('refs to trace:', len(seed), '(audit B:', sum(1 for s in seed.values() if 'audit_E_B' in s), ', audit A:', sum(1 for s in seed.values() if 'audit_E_A' in s), ', layout/anim:', sum(1 for s in seed.values() if 'layout_or_animation_ref' in s), ')')
tex = {v: exported_table(v, 'textureJSON') or {} for v in 'AB'}
keys = {v: {f'{d}/{n}': m for d, s in tex[v].items() for n, m in s.items()} for v in 'AB'}
base_idx = {v: collections.defaultdict(list) for v in 'AB'}
for v in 'AB':
    for k in keys[v]: base_idx[v][os.path.basename(k)].append(k)
files = {v: set(images(v)) for v in 'AB'}
file_base = {v: collections.defaultdict(list) for v in 'AB'}
for v in 'AB':
    for f in files[v]: file_base[v][os.path.basename(f)].append(f)
txtB = js_text('B')
def region(name):
    m = re.search(r'exports\.%s\s*=\s*' % name, txtB); o, e = json.JSONDecoder().raw_decode(txtB[m.end():]); return (m.end(), m.end() + e)
R_LB, R_AB = region('lbViewJSON'), region('ABJSON')
lb = exported_table('B', 'lbViewJSON'); ab = exported_table('B', 'ABJSON')
def carriers(ref):
    out = []
    for kind, tbl in (('layout', lb), ('animation', ab)):
        for n, o in tbl.items():
            if f'"{ref}"' in json.dumps(o, ensure_ascii=False): out.append(f'{kind}:{n}')
    return out
def code_hits(ref):
    hits = []
    for m in re.finditer(re.escape(ref), txtB):
        p = m.start()
        if not (txtB[p - 1] in '"\'' and txtB[p + len(ref)] in '"\''): continue
        if R_LB[0] <= p <= R_LB[1] or R_AB[0] <= p <= R_AB[1]: continue
        j = txtB.rfind("classname", 0, p); cn = re.match(r"classname\s*:\s*'(\w+)'", txtB[j:j + 60]) if j > 0 and p - j < 20000 else None
        pre = txtB[max(0, p - 160):p]; helper = re.findall(r'(BasePath\.\w+|modifyImagePath|getImageBase|Config\.assetHost|\.(?:changeImage|setImage|loadImage)\w*)\s*\(?', pre)
        hits.append({'class': cn.group(1) if cn else None, 'helpers': sorted(set(helper))})
    return hits
SERVER_CATS = {'card/': 'getFigurePath', 'map/': 'getZoneLoDPath', 'item/': 'getItemPath', 'gear/': 'getGearPath', 'region/': 'getRegionMapPath', 'boost/': 'getBoostIconPath',
               'arena_bg/': 'getArenaBackgroundPath', 'boardgame/': 'getBoardGame*Path', 'treasurehunt/': 'getTreasureHunt*Path', 'pact/': 'getGachaBannerPath'}

# ---- code regions that are tables / comments (needed to tell "table entry name" and "doc example" from real references)
def table_regions(name):
    out = []
    for m in re.finditer(r'exports\.%s\s*=\s*' % name, txtB):
        try: o, e = json.JSONDecoder().raw_decode(txtB[m.end():]); out.append((m.end(), m.end() + e))
        except Exception: pass
    return out
R_TEX = table_regions('textureJSON')
def in_regions(p, regs): return any(a <= p <= b for a, b in regs)
def in_block_comment(p): return txtB.rfind('/*', 0, p) > txtB.rfind('*/', 0, p)
SERVER_HELPERS = ('getRegionMapPath', 'getFigurePath', 'getItemPath', 'getGearPath', 'getBoostIconPath', 'getArenaBackgroundPath', 'getGachaBannerPath', 'getZoneLoDPath', 'getBoardGame', 'getTreasureHunt')
BG_CLASSES = {'ZoneProgressCache', 'RankingGachaBattle', 'EventZoneDataEntity'}
def all_hits(ref):
    out = []
    for m in re.finditer(re.escape(ref), txtB):
        p = m.start()
        if not (txtB[p - 1] in '"\'' and txtB[p + len(ref)] in '"\''): continue          # whole string literals only (not substrings of longer paths)
        out.append({'pos': p, 'tex': in_regions(p, R_TEX), 'lb': R_LB[0] <= p <= R_LB[1], 'ab': R_AB[0] <= p <= R_AB[1],
                                   'comment': in_block_comment(p), 'pre': txtB[max(0, p - 160):p], 'post': txtB[p:p + len(ref) + 260]})
    return out
rows = []
for ref in sorted(seed):
    ev = []; cls = None; rule = ''; apk_loc = ''; prj_loc = ''; sub = ''
    norm = ref
    for pre in ('/Content/lang/images/', './Content/lang/images/', 'Content/lang/images/'):
        if norm.startswith(pre): norm = norm[len(pre):]
    car = carriers(ref); hits = code_hits(ref); H = all_hits(ref)
    helpers = sorted({h for x in hits for h in x['helpers']}); classes = sorted({x['class'] for x in hits if x['class']})
    code_only = [h for h in H if not h['tex'] and not h['lb'] and not h['ab']]
    cand = []
    for v in 'BA':
        b = os.path.basename(norm)
        cand += [f'sprite:{k}(APK {v})' for k in base_idx[v].get(b, [])[:4]] + [f'file:{k}(APK {v})' for k in file_base[v].get(b, [])[:4]]
    cand = sorted(set(cand))
    # R1 explicit server marker
    if ref.startswith('[DOWNLOAD_CONTENT]') or 'DownloadContent' in ref or ref.startswith('http'):
        cls, rule = 'SERVER', 'R1_marker'; ev.append('path carries DownloadContent marker; BBUtil.isDownloadableImage/BasePath.modifyImagePath map it to Config.assetHost')
    # R2 exact resolution by the client rule (sprite table / file), APK B then A
    if not cls:
        for v in 'BA':
            if norm in keys[v]:
                cls, rule = 'FOUND_IN_APK', 'R2_exact'; apk_loc = f"{norm.rsplit('/',1)[0]}/{keys[v][norm]['src']} (sprite table, APK {v})"
                bundled = f"{norm.rsplit('/',1)[0]}/{keys[v][norm]['src']}" in files[v]
                ev.append(f'exact key in textureJSON of APK {v}; sheet bundled: {bundled}'); break
            if norm in files[v]:
                cls, rule = 'FOUND_IN_APK', 'R2_exact'; apk_loc = f'Content/lang/images/{norm} (APK {v})'; ev.append(f'file exists in APK {v}'); break
    # R3 name that only occurs as an entry inside textureJSON itself
    if not cls and H and not code_only and all(h['tex'] for h in H):
        m = [k for v in 'BA' for k in base_idx[v].get(norm, [])]
        for v in 'BA':
            for k in base_idx[v].get(norm, []):
                sheet = f"{k.rsplit('/',1)[0]}/{keys[v][k]['src']}"
                if sheet in files[v]:
                    cls, rule, apk_loc = 'FOUND_IN_APK', 'R3_table_entry_name', f'{k} -> sheet {sheet} (APK {v})'; ev.append('literal is a sprite NAME inside textureJSON (not a separate reference); the sprite exists in a bundled sheet'); break
            if cls: break
        if not cls:
            for v in 'BA':
                for k in base_idx[v].get(norm, []):
                    cls, rule = 'UNRESOLVED', 'R3b_table_sheet_not_bundled'; sub = 'sheet_not_bundled'
                    ev.append(f"literal is the 'src' sheet name of textureJSON entry {k}; sheet {k.rsplit('/',1)[0]}/{keys[v][k]['src']} is NOT bundled in APK {v}"); break
                if cls: break
        if not cls and norm == 'sheet1.png':
            cls, rule, sub = 'UNRESOLVED', 'R3b_table_sheet_not_bundled', 'sheet_not_bundled'; ev.append("literal is the 'src' sheet name of textureJSON entry deprecated_loot/lootfound.png; sheet deprecated_loot/sheet1.png is NOT bundled in either APK")
    # R4 SDK documentation example (all code hits inside /* */ comments)
    if not cls and code_only and all(h['comment'] for h in code_only):
        cls, rule = 'NOT_AN_ASSET_REFERENCE', 'R4_doc_comment'; ev.append('every occurrence is inside a /* */ documentation comment (SDK example text)')
    # R5 server by BasePath helper at the call site
    if not cls and any(any(sh in h for sh in SERVER_HELPERS) for h in helpers):
        cls, rule = 'SERVER', 'R5_basepath_helper'; ev.append('call site wraps the name with ' + ', '.join(h for h in helpers if any(sh in h for sh in SERVER_HELPERS)) + ' (DownloadContent/…, Config.assetHost)')
    # R6 server by BattleBackground (battle_bg/, arena_bg/)
    if not cls and (norm.startswith('battle_bg/') or norm.startswith('arena_bg/')) and (BG_CLASSES & set(classes)):
        cls, rule = 'SERVER', 'R6_battle_background'; ev.append("default background path returned to BattleBackground.setImage, which builds Config.assetHost + '/' + BasePath.getDownloadImageBase() + path; PreDownloader maps 'battle_bg' to category 'battleback'")
    # R7 dead default (function ignores it and returns another literal)
    if not cls and norm == 'post_effect/lava.png' and code_only and 'return "common/ui/zone/floor/grayout_layer.png"' in code_only[0]['post']:
        cls, rule = 'NOT_AN_ASSET_REFERENCE', 'R7_dead_default'; ev.append('assigned as a default but the method returns another literal (common/ui/zone/floor/grayout_layer.png), so this path is never loaded')
    # R8 suffix / dynamic fragment
    if not cls and '/' not in norm and code_only and any(re.search(r'(SUFFIX|\+\s*$|replace\(|\+\s*[\'"]$)', h['pre'].rstrip()[-40:]) or re.search(r'\+\s*[\'"]?$', h['pre'].rstrip()) or 'SUFFIX' in h['pre'][-60:] or 'replace(' in h['pre'][-60:] for h in code_only):
        cls, rule = 'NOT_AN_ASSET_REFERENCE', 'R8_suffix_fragment'; ev.append('literal is a suffix/fragment concatenated or substituted by the code (not a file name by itself)')
    # R9 everything else: client rule maps untagged paths to Content/lang/images/<path>
    if not cls:
        cls, rule = 'UNRESOLVED', 'R9_local_expected_absent'
        ev.append(f'no server marker/helper found; client rule (BBSPSprite.setImage -> BasePath.modifyImagePath) maps untagged paths to local "Content/lang/images/{norm}", which is absent from both APKs')
        if ref.startswith('lang/iamges/'):
            sub = 'malformed_path_typo'; fixed = ref.replace('lang/iamges/', '', 1); ev.append(f'path has a typo ("iamges"); normalised "{fixed}" also absent from sprite tables/files' if fixed not in keys['B'] and fixed not in files['B'] else f'normalised {fixed} exists')
        elif cand: sub = 'candidate_by_name_not_proven'
        elif any(h.startswith('layout:') or h.startswith('animation:') for h in car) and not code_only: sub = 'only_in_layout_or_animation_data'
        else: sub = 'referenced_by_code_target_absent'
        n_static = sum(1 for c in car if c.startswith('layout:'))
        if car and not code_only: ev.append('no static code reference to the carrying layout/animation found (does not prove it is unused: names can be built dynamically)')
    if cls == 'FOUND_IN_APK':
        rel = norm; prj = [p for p in (f'{PRJ}/ui/{rel}', f'{V2}/images/{rel}') if os.path.exists(p)]
        if not prj and rule == 'R3_table_entry_name':
            hit = [k for v in 'BA' for k in base_idx[v].get(norm, [])]; prj = [f'{PRJ}/ui/{k}' for k in hit if os.path.exists(f'{PRJ}/ui/{k}')]
        prj_loc = prj[0] if prj else ''
    rows.append({'reference': ref, 'normalised_path': norm, 'seen_via': '|'.join(sorted(seed[ref])), 'classification': cls, 'rule': rule, 'sub_reason': sub,
                 'in_project_assets': ('yes' if prj_loc else 'no') if cls == 'FOUND_IN_APK' else 'n/a', 'apk_location': apk_loc, 'project_location': prj_loc,
                 'carriers_layout_anim': ';'.join(car[:6]), 'code_classes': ';'.join(classes[:4]), 'code_helpers': ';'.join(helpers[:4]),
                 'basename_candidates': ';'.join(cand[:6]), 'evidence': ' | '.join(ev)})
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
c = collections.Counter(r['classification'] for r in rows); print('classification:', dict(c)); print('by rule:', dict(collections.Counter(r['rule'] for r in rows))); print('unresolved sub-reasons:', dict(collections.Counter(r['sub_reason'] for r in rows if r['classification']=='UNRESOLVED')))
print('FOUND_IN_APK in project assets:', collections.Counter(r['in_project_assets'] for r in rows if r['classification'] == 'FOUND_IN_APK'))
