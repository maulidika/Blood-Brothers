extends RefCounted
## Deterministic turn-based battle simulation. Mirrors tools/sim_battle.py (used for balancing).
## Lines: slot 0-1 = front, 2-3 = center, 4-5 = rear. Side 0 = player, side 1 = enemy.
## Reconstructed from the client's structure: 4 stats (ATK/DEF/WIS/AGI) + HP, AGI turn order,
## target ranges (front/rear/all/random), buff/debuff on stats, heal, drain, taunt.
const MAX_ROUNDS := 25

var units: Array = []
var events: Array = []
var rng := RandomNumberGenerator.new()
var result: String = ""
var rounds: int = 0

static func make_unit(fid: String, level: int, side: int, slot: int, mult: float, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = Data.fams[fid]
	var u: Dictionary = {
		"fid": fid, "name": str(d["name"]), "race": int(d["race"]), "rarity": int(d["rarity"]), "level": level,
		"side": side, "slot": slot, "skill_id": str(d["skill"]), "skill": Data.skills[str(d["skill"])],
		"buffs": [], "taunt": 0, "alive": true,
	}
	for k in ["hp", "atk", "def", "wis", "agi"]:
		u[k] = Data.stat_at(fid, k, level) * mult
	for k in extra.keys():
		if k in ["hp", "atk", "def", "wis", "agi"]:
			u[k] = float(u[k]) + float(extra[k])
		else:
			u[k] = extra[k]
	u["max_hp"] = u["hp"]
	return u

func setup(p_units: Array, seed_value: int) -> void:
	units = p_units
	for i in range(units.size()):
		units[i]["idx"] = i
	rng.seed = seed_value
	events = []
	result = ""
	rounds = 0

func eff(u: Dictionary, k: String) -> float:
	var p: float = 0.0
	for b in u["buffs"]:
		if b["stat"] == k:
			p += float(b["pct"])
	return maxf(1.0, float(u[k]) * clampf(1.0 + p, 0.3, 2.5))

func _alive(side: int) -> Array:
	var out: Array = []
	for u in units:
		if u["side"] == side and u["alive"]:
			out.append(u)
	return out

func _line_of(u: Dictionary) -> int:
	return int(u["slot"]) / 2

func _front_line(us: Array) -> Array:
	if us.is_empty():
		return []
	var m: int = 99
	for u in us:
		m = mini(m, _line_of(u))
	var out: Array = []
	for u in us:
		if _line_of(u) == m:
			out.append(u)
	return out

func _rear_line(us: Array) -> Array:
	if us.is_empty():
		return []
	var m: int = -1
	for u in us:
		m = maxi(m, _line_of(u))
	var out: Array = []
	for u in us:
		if _line_of(u) == m:
			out.append(u)
	return out

func _pick(arr: Array) -> Dictionary:
	return arr[rng.randi_range(0, arr.size() - 1)]

func _targets(src: Dictionary, kind: String) -> Array:
	var foes: Array = _alive(1 - int(src["side"]))
	var allies: Array = _alive(int(src["side"]))
	var taunters: Array = []
	for u in foes:
		if int(u["taunt"]) > 0:
			taunters.append(u)
	match kind:
		"front":
			var pool: Array = taunters if not taunters.is_empty() else _front_line(foes)
			return [_pick(pool)] if not pool.is_empty() else []
		"front_all":
			return _front_line(foes)
		"rear":
			var pool2: Array = _rear_line(foes)
			return [_pick(pool2)] if not pool2.is_empty() else []
		"all":
			return foes
		"random2", "random3":
			var n: int = int(kind.substr(kind.length() - 1))
			var out: Array = []
			if foes.is_empty():
				return out
			for i in range(n):
				out.append(_pick(foes))
			return out
		"self":
			return [src]
		"ally_all":
			return allies
		"ally_low":
			if allies.is_empty():
				return []
			var best: Dictionary = allies[0]
			for a in allies:
				if float(a["hp"]) / float(a["max_hp"]) < float(best["hp"]) / float(best["max_hp"]):
					best = a
			return [best]
	return []

func _hit(src: Dictionary, dst: Dictionary, mult: float, magic: bool) -> int:
	var d: float
	if magic:
		d = eff(src, "wis") * mult * 100.0 / (100.0 + eff(dst, "wis") * 0.5)
	else:
		d = eff(src, "atk") * mult * 100.0 / (100.0 + eff(dst, "def"))
	var dmg: int = maxi(1, int(round(d * rng.randf_range(0.9, 1.1))))
	dst["hp"] = float(dst["hp"]) - float(dmg)
	if float(dst["hp"]) <= 0.0:
		dst["hp"] = 0.0
		dst["alive"] = false
	return dmg

func _ev(e: Dictionary) -> void:
	events.append(e)

func _act(u: Dictionary) -> void:
	var sk: Dictionary = u["skill"]
	var use: bool = rng.randf() < float(sk["prob"])
	var tg: Array = []
	if use:
		tg = _targets(u, str(sk["range"]))
		if tg.is_empty():
			use = false
	if not use:
		tg = _targets(u, "front")
		sk = {"logic": "attack", "mult": 1.0, "name": "Attack"}
	if tg.is_empty():
		return
	var lg: String = str(sk["logic"])
	_ev({"t": "act", "src": int(u["idx"]), "skill": str(sk["name"]), "special": use})
	if lg == "attack" or lg == "magic" or lg == "drain":
		for t in tg:
			if not t["alive"]:
				continue
			var d: int = _hit(u, t, float(sk["mult"]), lg == "magic")
			if lg == "drain":
				u["hp"] = minf(float(u["max_hp"]), float(u["hp"]) + float(d) * 0.5)
			_ev({"t": "dmg", "src": int(u["idx"]), "dst": int(t["idx"]), "amount": d, "hp": float(t["hp"]),
				"kind": lg, "src_hp": float(u["hp"])})
			if not t["alive"]:
				_ev({"t": "down", "dst": int(t["idx"])})
	elif lg == "heal":
		for t in tg:
			var h: int = int(round(eff(u, "wis") * float(sk["mult"]) * rng.randf_range(0.95, 1.05)))
			t["hp"] = minf(float(t["max_hp"]), float(t["hp"]) + float(h))
			_ev({"t": "heal", "src": int(u["idx"]), "dst": int(t["idx"]), "amount": h, "hp": float(t["hp"])})
	elif lg == "buff" or lg == "debuff":
		for t in tg:
			t["buffs"].append({"stat": str(sk["stat"]), "pct": float(sk["pct"]), "turns": int(sk["turns"])})
			_ev({"t": "buff", "dst": int(t["idx"]), "stat": str(sk["stat"]), "up": float(sk["pct"]) > 0.0})
	elif lg == "taunt":
		u["taunt"] = int(sk["turns"]) + 1
		_ev({"t": "buff", "dst": int(u["idx"]), "stat": "taunt", "up": true})
	# tick this unit's timers
	var keep: Array = []
	for b in u["buffs"]:
		b["turns"] = int(b["turns"]) - 1
		if int(b["turns"]) > 0:
			keep.append(b)
	u["buffs"] = keep
	if int(u["taunt"]) > 0:
		u["taunt"] = int(u["taunt"]) - 1

func _order() -> Array:
	var order: Array = []
	for u in units:
		if u["alive"]:
			order.append(u)
	order.sort_custom(func(a, b):
		var aa: float = eff(a, "agi")
		var ba: float = eff(b, "agi")
		if aa != ba:
			return aa > ba
		if a["side"] != b["side"]:
			return a["side"] < b["side"]
		return a["slot"] < b["slot"])
	return order

## Runs the whole fight; returns "win" or "lose". `events` holds the replay.
func run() -> String:
	for r in range(MAX_ROUNDS):
		rounds = r + 1
		_ev({"t": "round", "n": rounds})
		for u in _order():
			if not u["alive"]:
				continue
			_act(u)
			if _alive(1).is_empty():
				result = "win"
				return result
			if _alive(0).is_empty():
				result = "lose"
				return result
	result = "lose"
	return result
