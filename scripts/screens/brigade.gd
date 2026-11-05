extends Control
## Brigade (party) formation: 3 lines x 2 slots, limited by a cost cap that grows with rank.
var main
var args: Dictionary = {}
const LINE_NAMES := ["Front", "Center", "Rear"]

func _ready() -> void:
	Assets.play_bgm("home")
	_render()

func _render() -> void:
	for c in get_children():
		c.queue_free()
	UI.sprite(self, "common/ui/background.png", Vector2(-10, 0))
	UI.label(self, "Brigade", Vector2(0, 34), 20, Color("f3d7a0"), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	var cost: int = Game.brigade_cost()
	UI.label(self, "Cost %d / %d" % [cost, Game.cost_cap()], Vector2(0, 62), 12, Color("ffd860") if cost <= Game.cost_cap() else Color("ff6a5a"), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	for line in range(3):
		UI.label(self, LINE_NAMES[line], Vector2(10, 92.0 + float(line) * 92.0), 11, Color("c9a77a"))
		for col in range(2):
			var slot: int = line * 2 + col
			var pos := Vector2(10.0 + float(col) * 152.0, 108.0 + float(line) * 92.0)
			var uid: String = str(Game.s["brigade"][slot])
			if uid != "" and Game.s["fams"].has(uid):
				UI.fam_tile(self, Game.fam(uid), pos, Vector2(148, 44))
				UI.label(self, "ATK %d  DEF %d" % [int(Game.fam_stat(uid, "atk")), int(Game.fam_stat(uid, "def"))], pos + Vector2(44, 44), 9, Color(1, 1, 1, 0.8))
			else:
				UI.panel(self, pos, Vector2(148, 44), Color(0.05, 0.04, 0.04, 0.7), 5)
				UI.label(self, "Empty", pos + Vector2(0, 12), 12, Color(0.6, 0.6, 0.6), 148, HORIZONTAL_ALIGNMENT_CENTER)
			var s: int = slot
			UI.hit(self, pos, Vector2(148, 44), func(): _pick(s))
	var hint := UI.label(self, "Front line takes hits first. Rear line is hit last (and by Snipe). AGI decides turn order.", Vector2(10, 384), 9, Color(1, 1, 1, 0.7), 300)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size = Vector2(300, 30)
	UI.text_button(self, "Familiars", Vector2(10, 430), Vector2(96, 34), func(): main.go("familiars"), "gray")
	UI.text_button(self, "Back", Vector2(224, 430), Vector2(86, 34), func(): main.go("home"), "black")

func _pick(slot: int) -> void:
	for c in get_children():
		if c.name == "PickLayer":
			c.queue_free()
	var layer := Control.new()
	layer.name = "PickLayer"
	layer.size = Vector2(UI.W, UI.H)
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.size = Vector2(UI.W, UI.H)
	layer.add_child(dim)
	UI.label(layer, "Choose a familiar for %s line" % LINE_NAMES[slot / 2], Vector2(0, 34), 14, Color("f3d7a0"), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	var ids: Array = []
	for uid in Game.fam_uids_sorted():
		ids.append(str(uid))
	var content: Control = UI.scroll(layer, Vector2(10, 60), Vector2(300, 332), 48.0 * ids.size())
	for i in range(ids.size()):
		var uid: String = ids[i]
		var y: float = 48.0 * float(i)
		var t: Control = UI.fam_tile(content, Game.fam(uid), Vector2(0, y), Vector2(300, 44))
		if Game.in_brigade(uid):
			t.modulate = Color(0.7, 0.7, 0.7)
			UI.label(content, "IN BRIGADE", Vector2(200, y + 4), 9, Color("ffd860"), 96, HORIZONTAL_ALIGNMENT_RIGHT)
		UI.hit(content, Vector2(0, y), Vector2(300, 44), func():
			var msg: String = Game.set_brigade_slot(slot, uid)
			if msg != "":
				main.toast(msg)
			layer.queue_free()
			_render())
	var empty_cb: Callable = func():
		Game.set_brigade_slot(slot, "")
		layer.queue_free()
		_render()
	UI.text_button(layer, "Empty slot", Vector2(30, 400), Vector2(120, 32), empty_cb, "gray")
	UI.text_button(layer, "Cancel", Vector2(170, 400), Vector2(120, 32), func(): layer.queue_free(), "black")
