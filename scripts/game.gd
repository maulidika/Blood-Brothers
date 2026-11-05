extends Node
## Player state, economy, progression and local save (replaces the Mobage servers).
signal changed
const ENERGY_REGEN_SEC := 180
const BattleEngine := preload("res://scripts/battle_engine.gd")
const SaveStore := preload("res://scripts/services/save_store.gd")

var s: Dictionary = {}
var store = SaveStore.new()   # swap for a remote/cloud store later (see docs/BACKEND_READINESS.md)
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	if not load_game():
		new_game()
	refresh_energy()

# ---------------------------------------------------------------- save / load
func new_game() -> void:
	s = {"version": 1, "name": "Wanderer", "rank": 1, "exp": 0, "gold": 3000, "blood": 10,
		"energy": 22, "energy_ts": int(Time.get_unix_time_from_system()), "next_uid": 1,
		"fams": {}, "gear": {}, "brigade": ["", "", "", "", "", ""], "cleared": {},
		"stats": {"battles": 0, "wins": 0, "pacts": 0}, "daily": ""}
	var start: Array = ["gate_guard", "ember_pup", "ember_pup", "thorn_archer", "bog_shaman", "field_medic"]
	for i in range(start.size()):
		var uid: String = add_fam(str(start[i]), 4)
		s["brigade"][i] = uid
	add_gear("rusted_blade")
	add_gear("leather_vest")
	save_game()
	changed.emit()

func save_game() -> void:
	store.save_state(s)

func load_game() -> bool:
	var loaded: Dictionary = store.load_state()
	if loaded.is_empty():
		return false
	s = loaded
	return true

func _commit() -> void:
	save_game()
	changed.emit()

# ---------------------------------------------------------------- energy / rank
func max_energy() -> int:
	return 20 + int(s["rank"]) * 2

func refresh_energy() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var cur: int = int(s["energy"])
	if cur >= max_energy():
		s["energy_ts"] = now
		return
	var gained: int = int(float(now - int(s["energy_ts"])) / float(ENERGY_REGEN_SEC))
	if gained > 0:
		s["energy"] = mini(max_energy(), cur + gained)
		s["energy_ts"] = int(s["energy_ts"]) + gained * ENERGY_REGEN_SEC
		if int(s["energy"]) >= max_energy():
			s["energy_ts"] = now

func seconds_to_next_energy() -> int:
	if int(s["energy"]) >= max_energy():
		return 0
	var now: int = int(Time.get_unix_time_from_system())
	return maxi(0, ENERGY_REGEN_SEC - (now - int(s["energy_ts"])))

func rank_exp_needed() -> int:
	return 40 + int(s["rank"]) * 30

func cost_cap() -> int:
	return 14 + 2 * int(s["rank"])

func add_rank_exp(n: int) -> int:
	var ups: int = 0
	s["exp"] = int(s["exp"]) + n
	while int(s["exp"]) >= rank_exp_needed():
		s["exp"] = int(s["exp"]) - rank_exp_needed()
		s["rank"] = int(s["rank"]) + 1
		s["energy"] = max_energy()
		s["blood"] = int(s["blood"]) + 1
		ups += 1
	return ups

func claim_daily() -> bool:
	var today: String = Time.get_date_string_from_system()
	if str(s.get("daily", "")) == today:
		return false
	s["daily"] = today
	s["gold"] = int(s["gold"]) + 500
	s["blood"] = int(s["blood"]) + 1
	s["energy"] = maxi(int(s["energy"]), max_energy())
	_commit()
	return true

# ---------------------------------------------------------------- familiars / gear
func add_fam(fid: String, level: int = 1) -> String:
	var uid: String = str(int(s["next_uid"]))
	s["next_uid"] = int(s["next_uid"]) + 1
	s["fams"][uid] = {"id": fid, "level": level, "exp": 0, "gear": ""}
	return uid

func add_gear(gid: String) -> String:
	var uid: String = str(int(s["next_uid"]))
	s["next_uid"] = int(s["next_uid"]) + 1
	s["gear"][uid] = {"id": gid, "level": 0}
	return uid

func fam(uid: String) -> Dictionary:
	return s["fams"].get(uid, {})

func fam_def(uid: String) -> Dictionary:
	return Data.fams[str(fam(uid)["id"])]

func fam_stat(uid: String, key: String) -> float:
	var f: Dictionary = fam(uid)
	var v: float = Data.stat_at(str(f["id"]), key, int(f["level"]))
	var gid: String = str(f.get("gear", ""))
	if gid != "" and s["gear"].has(gid):
		var g: Dictionary = s["gear"][gid]
		var gd: Dictionary = Data.gear[str(g["id"])]
		if str(gd["stat"]) == key:
			v += float(gd["val"]) * (1.0 + 0.2 * float(int(g["level"])))
	return v

func gear_bonus(uid: String) -> Dictionary:
	var out: Dictionary = {}
	var gid: String = str(fam(uid).get("gear", ""))
	if gid != "" and s["gear"].has(gid):
		var g: Dictionary = s["gear"][gid]
		var gd: Dictionary = Data.gear[str(g["id"])]
		out[str(gd["stat"])] = float(gd["val"]) * (1.0 + 0.2 * float(int(g["level"])))
	return out

func in_brigade(uid: String) -> bool:
	return s["brigade"].has(uid)

func brigade_cost() -> int:
	var c: int = 0
	for uid in s["brigade"]:
		if str(uid) != "" and s["fams"].has(str(uid)):
			c += int(fam_def(str(uid))["cost"])
	return c

func set_brigade_slot(slot: int, uid: String) -> String:
	if uid != "":
		var idx: int = s["brigade"].find(uid)
		if idx >= 0:
			s["brigade"][idx] = ""
	var prev: String = str(s["brigade"][slot])
	s["brigade"][slot] = uid
	if brigade_cost() > cost_cap():
		s["brigade"][slot] = prev
		return "Brigade cost would exceed the cap (%d)." % cost_cap()
	_commit()
	return ""

func fam_uids_sorted() -> Array:
	var ids: Array = s["fams"].keys()
	ids.sort_custom(func(a, b):
		var fa: Dictionary = s["fams"][a]
		var fb: Dictionary = s["fams"][b]
		var ra: int = int(Data.fams[str(fa["id"])]["rarity"])
		var rb: int = int(Data.fams[str(fb["id"])]["rarity"])
		if ra != rb:
			return ra > rb
		if int(fa["level"]) != int(fb["level"]):
			return int(fa["level"]) > int(fb["level"])
		return int(a) < int(b))
	return ids

## Adds exp to a familiar; returns number of levels gained.
func apply_exp(uid: String, amount: int) -> int:
	var f: Dictionary = fam(uid)
	var d: Dictionary = fam_def(uid)
	var cap: int = int(d["max_level"])
	var gained: int = 0
	if int(f["level"]) >= cap:
		return 0
	f["exp"] = int(f["exp"]) + amount
	while int(f["level"]) < cap and int(f["exp"]) >= Data.exp_to_next(int(f["level"]), int(d["rarity"])):
		f["exp"] = int(f["exp"]) - Data.exp_to_next(int(f["level"]), int(d["rarity"]))
		f["level"] = int(f["level"]) + 1
		gained += 1
	if int(f["level"]) >= cap:
		f["exp"] = 0
	return gained

func combine_cost(fodder: Array) -> int:
	var c: int = 0
	for u in fodder:
		c += 30 * int(fam(str(u))["level"]) + 50
	return c

func combine_exp(fodder: Array) -> int:
	var e: int = 0
	for u in fodder:
		e += int(fam_def(str(u))["base_exp"]) + 10 * int(fam(str(u))["level"])
	return e

func can_combine_with(target: String, other: String) -> bool:
	return other != target and not in_brigade(other)

func combine(target: String, fodder: Array) -> Dictionary:
	if fodder.is_empty():
		return {"ok": false, "msg": "Choose familiars to combine."}
	var cost: int = combine_cost(fodder)
	if int(s["gold"]) < cost:
		return {"ok": false, "msg": "Not enough gold (%d needed)." % cost}
	for u in fodder:
		if not can_combine_with(target, str(u)):
			return {"ok": false, "msg": "Invalid material."}
	var exp_gain: int = combine_exp(fodder)
	s["gold"] = int(s["gold"]) - cost
	for u in fodder:
		_remove_fam(str(u))
	var ups: int = apply_exp(target, exp_gain)
	_commit()
	return {"ok": true, "ups": ups, "exp": exp_gain}

func _remove_fam(uid: String) -> void:
	var gid: String = str(fam(uid).get("gear", ""))
	if gid != "" and s["gear"].has(gid):
		pass  # gear stays in the inventory, unequipped
	s["fams"].erase(uid)
	var idx: int = s["brigade"].find(uid)
	if idx >= 0:
		s["brigade"][idx] = ""

func sell_price(uid: String) -> int:
	return int(fam_def(uid)["sell"]) + 5 * int(fam(uid)["level"])

func sell(uid: String) -> Dictionary:
	if in_brigade(uid):
		return {"ok": false, "msg": "Remove it from the brigade first."}
	s["gold"] = int(s["gold"]) + sell_price(uid)
	_remove_fam(uid)
	_commit()
	return {"ok": true}

# ---- evolution
func evolve_target(uid: String) -> String:
	var t = fam_def(uid).get("evolves_to", null)
	return str(t) if t != null else ""

func evolve_gold(uid: String) -> int:
	var rar: String = str(int(fam_def(uid)["rarity"]))
	return int(Data.evo["gold"].get(rar, 0))

func evolve_copies(uid: String) -> Array:
	var out: Array = []
	var fid: String = str(fam(uid)["id"])
	for u in s["fams"].keys():
		if u != uid and str(s["fams"][u]["id"]) == fid and not in_brigade(u):
			out.append(u)
	return out

func evolve(uid: String, copy_uid: String) -> Dictionary:
	var t: String = evolve_target(uid)
	if t == "":
		return {"ok": false, "msg": "This familiar cannot evolve."}
	if not evolve_copies(uid).has(copy_uid):
		return {"ok": false, "msg": "Needs a spare copy of the same familiar."}
	var cost: int = evolve_gold(uid)
	if int(s["gold"]) < cost:
		return {"ok": false, "msg": "Not enough gold (%d needed)." % cost}
	s["gold"] = int(s["gold"]) - cost
	_remove_fam(copy_uid)
	var f: Dictionary = fam(uid)
	f["id"] = t
	var cap: int = int(Data.fams[t]["max_level"])
	f["level"] = mini(int(f["level"]), cap)
	f["exp"] = 0
	_commit()
	return {"ok": true, "to": t}

# ---- gear
func equip(uid: String, gid: String) -> void:
	for u in s["fams"].keys():
		if str(s["fams"][u].get("gear", "")) == gid:
			s["fams"][u]["gear"] = ""
	s["fams"][uid]["gear"] = gid
	_commit()

func unequip(uid: String) -> void:
	s["fams"][uid]["gear"] = ""
	_commit()

func enhance_cost(gid: String) -> int:
	var lv: int = int(s["gear"][gid]["level"])
	if lv >= 10:
		return -1
	return int(Data.enhance_gold[lv + 1])

func enhance(gid: String) -> Dictionary:
	var c: int = enhance_cost(gid)
	if c < 0:
		return {"ok": false, "msg": "Already at max level."}
	if int(s["gold"]) < c:
		return {"ok": false, "msg": "Not enough gold (%d needed)." % c}
	s["gold"] = int(s["gold"]) - c
	s["gear"][gid]["level"] = int(s["gear"][gid]["level"]) + 1
	_commit()
	return {"ok": true}

func gear_owner(gid: String) -> String:
	for u in s["fams"].keys():
		if str(s["fams"][u].get("gear", "")) == gid:
			return str(u)
	return ""

# ---- pact (gacha)
func pact_roll(tier: String) -> Dictionary:
	var t: Dictionary = Data.pact[tier]
	var cur: String = str(t["currency"])
	var cost: int = int(t["cost"])
	if int(s[cur]) < cost:
		return {"ok": false, "msg": "Not enough %s (%d needed)." % ["gold" if cur == "gold" else "blood coins", cost]}
	s[cur] = int(s[cur]) - cost
	var total: float = 0.0
	for k in t["rates"].keys():
		total += float(t["rates"][k])
	var roll: float = rng.randf() * total
	var rar: int = 1
	for k in t["rates"].keys():
		roll -= float(t["rates"][k])
		if roll <= 0.0:
			rar = int(k)
			break
	var pool: Array = []
	for fid in Data.fams.keys():
		if int(Data.fams[fid]["rarity"]) == rar:
			pool.append(fid)
	var fid: String = str(pool[rng.randi_range(0, pool.size() - 1)])
	var uid: String = add_fam(fid, 1)
	s["stats"]["pacts"] = int(s["stats"]["pacts"]) + 1
	_commit()
	return {"ok": true, "uid": uid, "fid": fid, "rarity": rar}

# ---------------------------------------------------------------- adventure
func stage_cleared(stage_id: String) -> bool:
	return s["cleared"].has(stage_id)

func zone_unlocked(zi: int) -> bool:
	var z: Dictionary = Data.zones[zi]
	if int(s["rank"]) < int(z["unlock_rank"]):
		return false
	if zi == 0:
		return true
	var prev: Dictionary = Data.zones[zi - 1]
	return stage_cleared(str(prev["stages"][prev["stages"].size() - 1]["id"]))

func stage_unlocked(zi: int, si: int) -> bool:
	if not zone_unlocked(zi):
		return false
	if si == 0:
		return true
	return stage_cleared(str(Data.zones[zi]["stages"][si - 1]["id"]))

func party_units() -> Array:
	var out: Array = []
	for slot in range(6):
		var uid: String = str(s["brigade"][slot])
		if uid == "" or not s["fams"].has(uid):
			continue
		var f: Dictionary = fam(uid)
		var extra: Dictionary = gear_bonus(uid)
		extra["uid"] = uid
		extra["name"] = str(Data.fams[str(f["id"])]["name"])
		out.append(BattleEngine.make_unit(str(f["id"]), int(f["level"]), 0, slot, 1.0, extra))
	return out

func enemy_units(stage: Dictionary) -> Array:
	var out: Array = []
	var pool: Array = stage["enemy_ids"]
	var cnt: int = int(stage["count"])
	for i in range(cnt):
		var fid: String = str(pool[i % pool.size()])
		var slot: int = mini(i, 5)
		out.append(BattleEngine.make_unit(fid, int(stage["level"]), 1, slot, float(stage["stat_mult"])))
	if bool(stage["boss"]) and stage["boss_id"] != null:
		out[0] = BattleEngine.make_unit(str(stage["boss_id"]), int(stage["level"]) + 1, 1, 0,
			float(stage["stat_mult"]) * float(stage["boss_mult"]))
		out[0]["is_boss"] = true
	return out

## Spends energy and prepares a fight. Returns {ok,msg,engine}.
func begin_stage(stage_id: String) -> Dictionary:
	var stage: Dictionary = Data.find_stage(stage_id)
	if stage.is_empty():
		return {"ok": false, "msg": "Unknown stage."}
	refresh_energy()
	var party: Array = party_units()
	if party.is_empty():
		return {"ok": false, "msg": "Your brigade is empty."}
	if int(s["energy"]) < int(stage["energy"]):
		return {"ok": false, "msg": "Not enough energy (%d needed)." % int(stage["energy"])}
	s["energy"] = int(s["energy"]) - int(stage["energy"])
	if int(s["energy"]) < max_energy() and int(s["energy"]) + int(stage["energy"]) >= max_energy():
		s["energy_ts"] = int(Time.get_unix_time_from_system())
	var eng = BattleEngine.new()
	eng.setup(party + enemy_units(stage), rng.randi())
	eng.run()
	s["stats"]["battles"] = int(s["stats"]["battles"]) + 1
	return {"ok": true, "engine": eng, "stage": stage}

## Applies rewards after the replay. Returns a summary dictionary.
func finish_stage(stage: Dictionary, won: bool) -> Dictionary:
	var out: Dictionary = {"won": won, "gold": 0, "exp": 0, "rank_ups": 0, "level_ups": [], "drops": [], "gear": ""}
	if won:
		s["stats"]["wins"] = int(s["stats"]["wins"]) + 1
		var first: bool = not stage_cleared(str(stage["id"]))
		s["cleared"][str(stage["id"])] = int(s["cleared"].get(str(stage["id"]), 0)) + 1
		out["gold"] = int(stage["gold"])
		out["exp"] = int(stage["exp"])
		s["gold"] = int(s["gold"]) + int(out["gold"])
		out["rank_ups"] = add_rank_exp(int(stage["exp"]) / 2)
		for uid in s["brigade"]:
			if str(uid) != "" and s["fams"].has(str(uid)):
				var ups: int = apply_exp(str(uid), int(stage["exp"]))
				if ups > 0:
					out["level_ups"].append({"uid": str(uid), "ups": ups})
		if first and bool(stage["boss"]):
			s["blood"] = int(s["blood"]) + 2
			out["blood"] = 2
		if rng.randf() < float(stage["drop_rate"]):
			var pool: Array = []
			var maxr: int = 3 if bool(stage["boss"]) else 2
			var minr: int = 2 if bool(stage["boss"]) else 1
			var cands: Array = stage["enemy_ids"].duplicate()
			if bool(stage["boss"]) and stage["boss_id"] != null:
				cands.append(str(stage["boss_id"]))
			for fid in cands:
				var r: int = int(Data.fams[str(fid)]["rarity"])
				if r >= minr and r <= maxr:
					pool.append(str(fid))
			if pool.is_empty():
				pool = [str(stage["enemy_ids"][0])]
			var fid2: String = str(pool[rng.randi_range(0, pool.size() - 1)])
			var uid2: String = add_fam(fid2, 1)
			out["drops"].append({"uid": uid2, "fid": fid2})
		var gear_chance: float = 0.5 if bool(stage["boss"]) else 0.08
		if rng.randf() < gear_chance:
			var gpool: Array = []
			var zi: int = int(Data.zone_of_stage(str(stage["id"]))["order"])
			for gid in Data.gear.keys():
				if int(Data.gear[gid]["rarity"]) <= mini(4, 1 + zi):
					gpool.append(str(gid))
			var gid2: String = str(gpool[rng.randi_range(0, gpool.size() - 1)])
			add_gear(gid2)
			out["gear"] = gid2
	_commit()
	return out
