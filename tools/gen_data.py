#!/usr/bin/env python3
"""Generates data/*.json — ORIGINAL content for the offline reconstruction.
The 2015 master data (cards, quests) lived on Mobage servers and is not in the APKs,
so names/numbers here are new; terminology (races, rarities, stats, ranges) follows the client."""
import json, os
os.makedirs('data', exist_ok=True)

RACES = {1:'Paragon',2:'Champion',3:'Highlander',4:'Darklander',5:'Westerner',6:'Easterner',
         7:'Ape',8:'Lizardman',9:'Dwarf',10:'Goblin',11:'Undead'}
RARITY = {1:'Common',2:'Uncommon',3:'Rare',4:'Epic',5:'Legendary',6:'Mythic'}

# ---- skills: logic in {attack,magic,heal,buff,debuff,drain,taunt}; range in {front,front_all,rear,all,random2,random3,self,ally_all,ally_low}
SKILLS = {
 'power_strike':{'name':'Power Strike','logic':'attack','range':'front','mult':1.7,'prob':0.35},
 'cleave':      {'name':'Cleave','logic':'attack','range':'front_all','mult':1.0,'prob':0.30},
 'arrow_volley':{'name':'Arrow Volley','logic':'attack','range':'random3','mult':0.8,'prob':0.35},
 'snipe':       {'name':'Snipe','logic':'attack','range':'rear','mult':1.8,'prob':0.35},
 'fire_bolt':   {'name':'Fire Bolt','logic':'magic','range':'front','mult':1.8,'prob':0.35},
 'meteor':      {'name':'Meteor','logic':'magic','range':'all','mult':0.85,'prob':0.28},
 'mend':        {'name':'Mend','logic':'heal','range':'ally_low','mult':1.6,'prob':0.40},
 'sanctuary':   {'name':'Sanctuary','logic':'heal','range':'ally_all','mult':0.7,'prob':0.28},
 'war_cry':     {'name':'War Cry','logic':'buff','range':'ally_all','stat':'atk','pct':0.25,'turns':3,'prob':0.30},
 'iron_wall':   {'name':'Iron Wall','logic':'buff','range':'ally_all','stat':'def','pct':0.30,'turns':3,'prob':0.30},
 'hex':         {'name':'Hex','logic':'debuff','range':'front_all','stat':'atk','pct':-0.30,'turns':3,'prob':0.35},
 'sunder':      {'name':'Sunder','logic':'debuff','range':'front','stat':'def','pct':-0.40,'turns':3,'prob':0.40},
 'drain_touch': {'name':'Drain Touch','logic':'drain','range':'front','mult':1.3,'prob':0.35},
 'bulwark':     {'name':'Bulwark','logic':'taunt','range':'self','mult':0,'prob':0.30,'turns':2},
 'frenzy':      {'name':'Frenzy','logic':'buff','range':'self','stat':'atk','pct':0.50,'turns':3,'prob':0.35},
 'crushing_blow':{'name':'Crushing Blow','logic':'attack','range':'front','mult':2.4,'prob':0.25},
}

# role -> (hp, atk, def, wis, agi) multipliers around a base 100 budget
ROLES = {'striker':(0.9,1.25,0.8,0.5,1.0),'tank':(1.4,0.7,1.4,0.6,0.6),'mage':(0.8,0.5,0.7,1.4,0.9),
         'healer':(1.0,0.5,0.9,1.3,0.8),'scout':(0.85,1.0,0.7,0.7,1.5),'brute':(1.3,1.2,1.0,0.4,0.7)}
RMULT = {1:1.0,2:1.25,3:1.6,4:2.05,5:2.6,6:3.3}
MAXLV = {1:20,2:25,3:30,4:40,5:50,6:60}
COST  = {1:2,2:3,3:4,4:5,5:6,6:7}

# (id, name, race, rarity, role, skill, evolves_to)
LINES = [
 ('ember_pup','Ember Pup',7,1,'striker','power_strike','ember_hound'),
 ('ember_hound','Ember Hound',7,2,'striker','frenzy',None),
 ('gate_guard','Gate Guard',3,1,'tank','bulwark','bastion_warden'),
 ('bastion_warden','Bastion Warden',3,2,'tank','iron_wall',None),
 ('bog_shaman','Bog Shaman',8,1,'mage','fire_bolt','mire_oracle'),
 ('mire_oracle','Mire Oracle',8,2,'mage','meteor',None),
 ('field_medic','Field Medic',1,1,'healer','mend','battle_priest'),
 ('battle_priest','Battle Priest',1,2,'healer','sanctuary',None),
 ('thorn_archer','Thorn Archer',6,1,'scout','arrow_volley','glade_ranger'),
 ('glade_ranger','Glade Ranger',6,2,'scout','snipe',None),
 ('stone_brute','Stone Brute',9,2,'brute','crushing_blow','forge_titan'),
 ('forge_titan','Forge Titan',9,3,'brute','cleave',None),
 ('night_cutpurse','Night Cutpurse',10,2,'scout','sunder','shade_assassin'),
 ('shade_assassin','Shade Assassin',10,3,'scout','snipe',None),
 ('grave_whisper','Grave Whisper',11,2,'mage','hex','crypt_lich'),
 ('crypt_lich','Crypt Lich',11,3,'mage','drain_touch',None),
 ('dawn_knight','Dawn Knight',2,3,'striker','cleave','solar_paladin'),
 ('solar_paladin','Solar Paladin',2,4,'striker','war_cry',None),
 ('ash_witch','Ash Witch',4,3,'mage','fire_bolt','cinder_empress'),
 ('cinder_empress','Cinder Empress',4,4,'mage','meteor',None),
 ('iron_marshal','Iron Marshal',5,4,'tank','iron_wall',None),
 ('crimson_sovereign','Crimson Sovereign',4,5,'striker','crushing_blow',None),
 ('the_pale_regent','The Pale Regent',11,5,'mage','drain_touch',None),
 ('hollow_crown_king','Hollow Crown King',4,6,'brute','meteor',None),
]
fams = {}
for fid,name,race,rar,role,sk,evo in LINES:
    m = RMULT[rar]; r = ROLES[role]
    fams[fid] = {'name':name,'race':race,'rarity':rar,'role':role,'skill':sk,'evolves_to':evo,
        'cost':COST[rar],'max_level':MAXLV[rar],
        'hp':round(70*m*r[0]),'atk':round(18*m*r[1]),'def':round(14*m*r[2]),'wis':round(18*m*r[3]),'agi':round(14*m*r[4]),
        'growth':0.10 + 0.01*rar,   # +x of base stat per level
        'base_exp':20*rar*rar, 'sell':40*rar*rar}
# evolution cost: needs 1 extra copy of the same familiar + gold
EVO = {'gold':{1:800,2:2500,3:8000,4:20000},'copies':1}

# ---- zones: 5 zones x 6 stages (6th = boss)
ZONES = [
 ('ashen_frontier','Ashen Frontier',['ember_pup','gate_guard','thorn_archer','bog_shaman'],'ember_hound',3),
 ('mire_of_whispers','Mire of Whispers',['bog_shaman','night_cutpurse','grave_whisper','field_medic'],'mire_oracle',7),
 ('ironvale_pass','Ironvale Pass',['stone_brute','gate_guard','thorn_archer','night_cutpurse'],'forge_titan',12),
 ('crimson_wastes','Crimson Wastes',['dawn_knight','ash_witch','stone_brute','grave_whisper'],'cinder_empress',18),
 ('hollow_crown','The Hollow Crown',['iron_marshal','crypt_lich','shade_assassin','solar_paladin'],'hollow_crown_king',25),
]
zones=[]
for zi,(zid,zn,pool,boss,lv0) in enumerate(ZONES):
    stages=[]
    for si in range(6):
        isboss = si==5
        lvl = lv0 + si*1.0 + (2 if isboss else 0)
        n = 2+ (si//2) if not isboss else 4
        stages.append({'id':f'{zid}_{si+1}','name':f'{zn} {zi+1}-{si+1}' + (' (Boss)' if isboss else ''),
            'energy':2+zi+(1 if isboss else 0)+(si//3), 'boss':isboss,
            'level':round(lvl), 'enemy_ids':pool, 'count':n, 'boss_id':boss if isboss else None,
            'stat_mult': (1.0 + si*0.04) * (1.05 if isboss else 1.0), 'boss_mult': 1.25,
            'exp': round(36*(1+zi*0.9)*(1+si*0.15)), 'gold': round(60*(1+zi*1.1)*(1+si*0.12))*(3 if isboss else 1),
            'drop_rate': 0.35 if not isboss else 1.0})
    zones.append({'id':zid,'name':zn,'order':zi+1,'unlock_rank':[1,5,10,16,23][zi],'stages':stages})

GEAR = {
 'rusted_blade':{'name':'Rusted Blade','slot':'weapon','rarity':1,'stat':'atk','val':8},
 'hunters_bow':{'name':"Hunter's Bow",'slot':'weapon','rarity':2,'stat':'atk','val':16},
 'rune_staff':{'name':'Rune Staff','slot':'weapon','rarity':3,'stat':'wis','val':26},
 'leather_vest':{'name':'Leather Vest','slot':'armor','rarity':1,'stat':'def','val':8},
 'chain_mail':{'name':'Chain Mail','slot':'armor','rarity':2,'stat':'def','val':16},
 'dragonscale':{'name':'Dragonscale Plate','slot':'armor','rarity':4,'stat':'hp','val':140},
 'swift_charm':{'name':'Swift Charm','slot':'charm','rarity':2,'stat':'agi','val':12},
 'vital_charm':{'name':'Vital Charm','slot':'charm','rarity':3,'stat':'hp','val':90},
}
PACT = {
 'copper':{'name':'Copper Cloister','currency':'gold','cost':600,'rates':{1:60,2:32,3:7,4:1}},
 'silver':{'name':'Silver Cloister','currency':'gold','cost':4000,'rates':{2:45,3:40,4:13,5:2}},
 'gold':{'name':'Gold Cloister','currency':'blood','cost':5,'rates':{3:50,4:38,5:10,6:2}},
}
json.dump({'races':RACES,'rarity':RARITY,'familiars':fams,'evolution':EVO,'level_exp_base':30},open('data/familiars.json','w'),indent=1)
json.dump(SKILLS,open('data/skills.json','w'),indent=1)
json.dump({'zones':zones},open('data/zones.json','w'),indent=1)
json.dump({'gear':GEAR,'pact':PACT,'enhance_gold':[0,200,300,450,650,900,1300,1800,2500,3400,4600]},open('data/misc.json','w'),indent=1)
print('familiars',len(fams),'skills',len(SKILLS),'zones',len(zones))
