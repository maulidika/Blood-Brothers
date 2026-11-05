extends Control
var main
var args: Dictionary = {}
var zi: int = -1

func _ready() -> void:
	Assets.play_bgm("home")
	UI.sprite(self, "common/ui/background.png", Vector2(-10, 0))
	zi = int(args.get("zone", -1))
	if zi < 0:
		_zones()
	else:
		_stages()

func _zones() -> void:
	if Assets.tex("common/world/worldmap.png") != null:
		UI.sprite(self, "common/world/worldmap.png", Vector2.ZERO, Vector2(UI.W, UI.H))   # original RegionSelect backdrop
	UI.label(self, "Adventure", Vector2(0, 36), 20, Color("f3d7a0"), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	var content: Control = UI.scroll(self, Vector2(10, 70), Vector2(300, 350), 70.0 * Data.zones.size())
	for i in range(Data.zones.size()):
		var z: Dictionary = Data.zones[i]
		var y: float = 70.0 * float(i)
		var open: bool = Game.zone_unlocked(i)
		UI.panel(content, Vector2(0, y), Vector2(300, 62), Color(0.1, 0.06, 0.05, 0.88) if open else Color(0.05, 0.05, 0.05, 0.88), 6)
		UI.label(content, str(z["name"]), Vector2(12, y + 6), 15, Color.WHITE if open else Color(0.6, 0.6, 0.6))
		var done: int = 0
		for st in z["stages"]:
			if Game.stage_cleared(str(st["id"])):
				done += 1
		if open:
			UI.label(content, "Cleared %d / %d" % [done, z["stages"].size()], Vector2(12, y + 34), 11, Color("c9a77a"))
			var idx: int = i
			UI.hit(content, Vector2(0, y), Vector2(300, 62), func(): main.go("adventure", {"zone": idx}))
		else:
			UI.sprite(content, "common/region/padlock.png", Vector2(256, y + 14), Vector2(34, 34))
			var why: String = "Reach Rank %d" % int(z["unlock_rank"]) if int(Game.s["rank"]) < int(z["unlock_rank"]) else "Defeat the previous zone boss"
			UI.label(content, why, Vector2(12, y + 34), 11, Color(0.7, 0.55, 0.45))
	UI.text_button(self, "Back", Vector2(10, 440), Vector2(90, 30), func(): main.go("home"), "black")
	UI.text_button(self, "Brigade", Vector2(220, 440), Vector2(90, 30), func(): main.go("brigade"), "gray")

func _stages() -> void:
	var z: Dictionary = Data.zones[zi]
	UI.label(self, str(z["name"]), Vector2(0, 36), 18, Color("f3d7a0"), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	var content: Control = UI.scroll(self, Vector2(10, 70), Vector2(300, 350), 56.0 * z["stages"].size())
	for i in range(z["stages"].size()):
		var st: Dictionary = z["stages"][i]
		var y: float = 56.0 * float(i)
		var open: bool = Game.stage_unlocked(zi, i)
		var boss: bool = bool(st["boss"])
		var col := Color(0.25, 0.06, 0.05, 0.9) if boss else Color(0.1, 0.06, 0.05, 0.88)
		UI.panel(content, Vector2(0, y), Vector2(300, 50), col if open else Color(0.05, 0.05, 0.05, 0.88), 6)
		UI.label(content, str(st["name"]), Vector2(12, y + 4), 13, Color.WHITE if open else Color(0.55, 0.55, 0.55))
		UI.label(content, "Lv %d   Energy %d" % [int(st["level"]), int(st["energy"])], Vector2(12, y + 27), 10, Color("c9a77a"))
		if Game.stage_cleared(str(st["id"])):
			UI.label(content, "CLEAR", Vector2(230, y + 14), 12, Color("7fdc7f"))
		if open:
			var sid: String = str(st["id"])
			UI.hit(content, Vector2(0, y), Vector2(300, 50), func(): _prompt(sid))
	UI.text_button(self, "Back", Vector2(10, 440), Vector2(90, 30), func(): main.go("adventure"), "black")
	UI.text_button(self, "Brigade", Vector2(220, 440), Vector2(90, 30), func(): main.go("brigade"), "gray")

func _prompt(sid: String) -> void:
	var st: Dictionary = Data.find_stage(sid)
	var names: Array = []
	for u in Game.party_units():
		names.append("%s Lv%d" % [str(u["name"]), int(u["level"])])
	var body: String = "Enemy level %d%s\nEnergy cost: %d (you have %d)\n\nBrigade: %s" % [int(st["level"]),
		"  - BOSS" if bool(st["boss"]) else "", int(st["energy"]), int(Game.s["energy"]), ", ".join(names)]
	main.dialog(str(st["name"]), body, [{"text": "Cancel", "style": "gray"}, {"text": "Battle", "cb": func(): _start(sid)}], 200.0)

func _start(sid: String) -> void:
	var r: Dictionary = Game.begin_stage(sid)
	if not bool(r["ok"]):
		main.toast(str(r["msg"]))
		return
	main.go("battle", {"engine": r["engine"], "stage": r["stage"]})
