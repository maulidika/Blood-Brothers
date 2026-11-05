extends Node
## Static game data (data/*.json). JSON numbers arrive as floats, so always int()/float() on use.
var races: Dictionary = {}
var rarity_names: Dictionary = {}
var fams: Dictionary = {}
var skills: Dictionary = {}
var zones: Array = []
var gear: Dictionary = {}
var pact: Dictionary = {}
var enhance_gold: Array = []
var evo: Dictionary = {}

func _ready() -> void:
	var f: Dictionary = _load("res://data/familiars.json")
	races = f.get("races", {})
	rarity_names = f.get("rarity", {})
	fams = f.get("familiars", {})
	evo = f.get("evolution", {})
	skills = _load("res://data/skills.json")
	zones = _load("res://data/zones.json").get("zones", [])
	var m: Dictionary = _load("res://data/misc.json")
	gear = m.get("gear", {})
	pact = m.get("pact", {})
	enhance_gold = m.get("enhance_gold", [])

func _load(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("missing data file " + path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func race_name(r: int) -> String:
	return str(races.get(str(r), "?"))

func rarity_name(r: int) -> String:
	return str(rarity_names.get(str(r), "?"))

func stat_at(fid: String, key: String, level: int) -> float:
	var d: Dictionary = fams[fid]
	return float(d[key]) * (1.0 + float(d["growth"]) * float(level - 1))

func exp_to_next(level: int, rarity: int) -> int:
	return int(float(10 + 8 * level + level * level) * (1.0 + 0.2 * float(rarity - 1)))

func find_stage(stage_id: String) -> Dictionary:
	for z in zones:
		for st in z["stages"]:
			if st["id"] == stage_id:
				return st
	return {}

func zone_of_stage(stage_id: String) -> Dictionary:
	for z in zones:
		for st in z["stages"]:
			if st["id"] == stage_id:
				return z
	return {}

func range_text(kind: String) -> String:
	var m := {"front": "front enemy", "front_all": "front line", "rear": "rear enemy", "all": "all enemies",
		"random2": "2 random enemies", "random3": "3 random enemies", "self": "self",
		"ally_all": "all allies", "ally_low": "weakest ally"}
	return str(m.get(kind, kind))

func skill_text(sk: Dictionary) -> String:
	var lg: String = str(sk["logic"])
	var pr: int = int(round(float(sk["prob"]) * 100.0))
	var body: String = ""
	match lg:
		"attack":
			body = "Physical x%.1f to %s" % [float(sk["mult"]), range_text(str(sk["range"]))]
		"magic":
			body = "Magic x%.1f to %s" % [float(sk["mult"]), range_text(str(sk["range"]))]
		"drain":
			body = "Drain x%.1f from %s" % [float(sk["mult"]), range_text(str(sk["range"]))]
		"heal":
			body = "Heal x%.1f on %s" % [float(sk["mult"]), range_text(str(sk["range"]))]
		"buff", "debuff":
			var pct: int = int(round(float(sk["pct"]) * 100.0))
			body = "%s %+d%% for %d turns on %s" % [str(sk["stat"]).to_upper(), pct, int(sk["turns"]), range_text(str(sk["range"]))]
		"taunt":
			body = "Draws all attacks for %d turns" % int(sk["turns"])
		_:
			body = lg
	return "%s (%d%%): %s" % [str(sk["name"]), pr, body]
