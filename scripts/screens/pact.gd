extends Control
## Forge Pact: offline replacement of the gacha. Copper/Silver cloisters cost gold, Gold costs blood coins.
var main
var args: Dictionary = {}
const TIERS := ["copper", "silver", "gold"]
var tier: String = "copper"

func _ready() -> void:
	Assets.play_bgm("gacha")
	_render()

func _render() -> void:
	for c in get_children():
		c.queue_free()
	UI.sprite(self, "common/pact/bg.png", Vector2.ZERO, Vector2(UI.W, UI.H))
	UI.label(self, "Forge Pact", Vector2(0, 34), 20, Color("f3d7a0"), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	for i in range(TIERS.size()):
		var t: String = TIERS[i]
		var x: float = 30.0 + float(i) * 96.0
		var b: TextureButton = UI.tex_button(self, "common/pact/btn_%s_cloister.png" % t, "", Vector2(x, 76), func():
			tier = t
			_render())
		if t != tier:
			b.modulate = Color(0.55, 0.55, 0.55)
		UI.label(self, str(Data.pact[t]["name"]).replace(" Cloister", ""), Vector2(x - 6, 154), 11, Color.WHITE, 80, HORIZONTAL_ALIGNMENT_CENTER)
	var p: Dictionary = Data.pact[tier]
	UI.panel(self, Vector2(20, 184), Vector2(280, 150), Color(0.08, 0.04, 0.04, 0.9), 8)
	UI.label(self, str(p["name"]), Vector2(0, 190), 15, Color("f3d7a0"), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	var total: float = 0.0
	for k in p["rates"].keys():
		total += float(p["rates"][k])
	var ys: float = 216.0
	for k in p["rates"].keys():
		var r: int = int(k)
		UI.label(self, "%s %s" % [UI.stars(r), Data.rarity_name(r)], Vector2(60, ys), 12, UI.rarity_color(r))
		UI.label(self, "%.0f%%" % (float(p["rates"][k]) / total * 100.0), Vector2(200, ys), 12, Color.WHITE, 60, HORIZONTAL_ALIGNMENT_RIGHT)
		ys += 20.0
	var cur: String = "gold" if str(p["currency"]) == "gold" else "blood coins"
	UI.text_button(self, "Forge Pact  (%d %s)" % [int(p["cost"]), cur], Vector2(40, 352), Vector2(240, 40), _forge)
	UI.label(self, "You have: %d gold, %d blood coins" % [int(Game.s["gold"]), int(Game.s["blood"])], Vector2(0, 400), 11, Color("c9a77a"), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	UI.text_button(self, "Back", Vector2(110, 436), Vector2(100, 30), func(): main.go("home"), "black")

func _forge() -> void:
	var r: Dictionary = Game.pact_roll(tier)
	if not bool(r["ok"]):
		main.toast(str(r["msg"]))
		return
	Assets.sfx("forge_pact_blood" if tier == "gold" else "forge_pact")
	_render()
	var d: Dictionary = Data.fams[str(r["fid"])]
	var layer := Control.new()
	layer.size = Vector2(UI.W, UI.H)
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.size = Vector2(UI.W, UI.H)
	layer.add_child(dim)
	UI.label(layer, "A pact is sealed!", Vector2(0, 120), 18, Color("f3d7a0"), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	UI.race_icon(layer, int(d["race"]), Vector2(110, 160), 100.0)
	UI.label(layer, str(d["name"]), Vector2(0, 270), 20, Color.WHITE, UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(layer, "%s %s  -  %s" % [UI.stars(int(r["rarity"])), Data.rarity_name(int(r["rarity"])), Data.race_name(int(d["race"]))], Vector2(0, 298), 13, UI.rarity_color(int(r["rarity"])), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(layer, Data.skill_text(Data.skills[str(d["skill"])]), Vector2(20, 324), 10, Color(1, 1, 1, 0.85), 280, HORIZONTAL_ALIGNMENT_CENTER)
	UI.text_button(layer, "Again", Vector2(40, 380), Vector2(110, 36), func():
		layer.queue_free()
		_forge())
	UI.text_button(layer, "OK", Vector2(170, 380), Vector2(110, 36), func(): layer.queue_free(), "gray")
	if int(r["rarity"]) >= 4:
		Assets.sfx("get_treasure")
