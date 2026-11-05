#!/usr/bin/env python3
"""Reference implementation of scripts/battle_engine.gd used to balance data/*.json offline."""
import json, random, statistics, sys
F=json.load(open('data/familiars.json')); S=json.load(open('data/skills.json')); Z=json.load(open('data/zones.json'))['zones']
FAM=F['familiars']
def stat(fid,key,lv):
    f=FAM[fid]; return f[key]*(1+f['growth']*(lv-1))
def make_unit(fid,lv,side,slot,mult=1.0,gear=None):
    f=FAM[fid]
    u={'id':fid,'name':f['name'],'side':side,'slot':slot,'skill':S[f['skill']],'buffs':[],'taunt':0,'alive':True}
    for k in ('hp','atk','def','wis','agi'): u[k]=stat(fid,k,lv)*mult
    u['max_hp']=u['hp']; return u
def eff(u,k):
    p=sum(b['pct'] for b in u['buffs'] if b['stat']==k)
    return max(1.0,u[k]*min(2.5,max(0.3,1+p)))
def line_of(slot): return slot//2
def alive(units,side): return [u for u in units if u['side']==side and u['alive']]
def front_line(us):
    if not us: return []
    m=min(line_of(u['slot']) for u in us); return [u for u in us if line_of(u['slot'])==m]
def rear_line(us):
    if not us: return []
    m=max(line_of(u['slot']) for u in us); return [u for u in us if line_of(u['slot'])==m]
def targets(units,src,rng_kind,rnd):
    foes=alive(units,1-src['side']); allies=alive(units,src['side'])
    taunters=[u for u in foes if u['taunt']>0]
    if rng_kind=='front':
        pool=taunters if taunters else front_line(foes); return [rnd.choice(pool)] if pool else []
    if rng_kind=='front_all': return front_line(foes)
    if rng_kind=='rear': pool=rear_line(foes); return [rnd.choice(pool)] if pool else []
    if rng_kind=='all': return foes
    if rng_kind in('random2','random3'):
        n=int(rng_kind[-1]); return [rnd.choice(foes) for _ in range(n)] if foes else []
    if rng_kind=='self': return [src]
    if rng_kind=='ally_all': return allies
    if rng_kind=='ally_low': return [min(allies,key=lambda u:u['hp']/u['max_hp'])] if allies else []
    return []
def hit(src,dst,mult,magic,rnd):
    if magic: raw=eff(src,'wis')*mult; d=raw*100/(100+eff(dst,'wis')*0.5)
    else: raw=eff(src,'atk')*mult; d=raw*100/(100+eff(dst,'def'))
    d=max(1,round(d*rnd.uniform(0.9,1.1))); dst['hp']-=d
    if dst['hp']<=0: dst['hp']=0; dst['alive']=False
    return d
def act(units,u,rnd,events):
    sk=u['skill']; use=rnd.random()<sk['prob']
    if use:
        tg=targets(units,u,sk['range'],rnd)
        if not tg: use=False
    if not use:
        tg=targets(units,u,'front',rnd); sk={'logic':'attack','mult':1.0,'name':'Attack'}
    lg=sk['logic']
    if lg in('attack','magic','drain'):
        for t in tg:
            if not t['alive']: continue
            d=hit(u,t,sk['mult'],lg=='magic',rnd)
            if lg=='drain': u['hp']=min(u['max_hp'],u['hp']+d*0.5)
            events.append(('dmg',u['name'],t['name'],d))
    elif lg=='heal':
        for t in tg:
            h=round(eff(u,'wis')*sk['mult']*rnd.uniform(0.95,1.05)); t['hp']=min(t['max_hp'],t['hp']+h); events.append(('heal',u['name'],t['name'],h))
    elif lg in('buff','debuff'):
        for t in tg: t['buffs'].append({'stat':sk['stat'],'pct':sk['pct'],'turns':sk['turns']})
    elif lg=='taunt': u['taunt']=sk['turns']
    for b in u['buffs']: b['turns']-=1
    u['buffs']=[b for b in u['buffs'] if b['turns']>0]
    if u['taunt']>0: u['taunt']-=1
def battle(units,rnd,max_rounds=25):
    for r in range(max_rounds):
        order=sorted([u for u in units if u['alive']],key=lambda u:(-eff(u,'agi'),u['side'],u['slot']))
        for u in order:
            if not u['alive']: continue
            act(units,u,rnd,[])
            if not alive(units,1): return 'win',r+1
            if not alive(units,0): return 'lose',r+1
    return 'lose',max_rounds
def enemy_party(stage):
    units=[]
    pool=stage['enemy_ids']; cnt=stage['count']; rnd=random.Random(hash(stage['id'])&0xffff)
    for i in range(cnt):
        fid=pool[i%len(pool)]; slot=[0,1,2,3,4,5][i] if i<6 else 5
        units.append(make_unit(fid,stage['level'],1,slot,stage['stat_mult']))
    if stage['boss']:
        units[0]=make_unit(stage['boss_id'],stage['level']+1,1,0,stage['stat_mult']*stage['boss_mult'])
    return units
def player_party(spec):
    return [make_unit(fid,lv,0,i) for i,(fid,lv) in enumerate(spec)]
def winrate(spec,stage,n=300):
    w=0;rs=[]
    for i in range(n):
        us=player_party(spec)+enemy_party(stage); r,rounds=battle(us,random.Random(i)); w+=(r=='win'); rs.append(rounds)
    return w/n,statistics.mean(rs)
if __name__=='__main__':
    starters=[('gate_guard',1),('ember_pup',1),('thorn_archer',1),('field_medic',1),('bog_shaman',1)]
    tests=[('starter lv5',[(f,5) for f,_ in starters],0,[0,1,2,3,4,5]),
           ('starter lv10',[(f,10) for f,_ in starters],0,[0,1,2,3,4,5]),
           ('mid party lv16',[('bastion_warden',16),('ember_hound',16),('glade_ranger',16),('battle_priest',16),('mire_oracle',16),('forge_titan',16)],1,[0,2,4,5]),
           ('mid party lv22',[('bastion_warden',22),('ember_hound',22),('glade_ranger',22),('battle_priest',22),('mire_oracle',22),('forge_titan',22)],2,[0,2,4,5]),
           ('late party lv35',[('iron_marshal',35),('solar_paladin',35),('shade_assassin',35),('battle_priest',35),('cinder_empress',35),('crimson_sovereign',35)],3,[0,2,4,5]),
           ('end party lv45',[('iron_marshal',45),('solar_paladin',45),('shade_assassin',45),('battle_priest',45),('cinder_empress',45),('crimson_sovereign',45)],4,[0,2,4,5])]
    for name,spec,z,sts in tests:
        print(name,'vs zone',z+1)
        for si in sts:
            st=Z[z]['stages'][si]; wr,rr=winrate(spec,st,200); print(f'   stage {si+1} lv{st["level"]}: win {wr:.0%}, avg rounds {rr:.1f}')
