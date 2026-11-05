extends Control
## Bazaar: gear inventory and enhancement (v2.5.3.1.0 added gear).
var main
var args: Dictionary = {}

func _ready() -> void:
	Assets.play_bgm("home")
	_render()

func _render() -> void:
	for c in get_children():
		c.queue_free()
	UI.sprite(self, "common/ui/background.png", Vector2(-10, 0))
	UI.label(self, "Bazaar - Gear", Vector2(0, 34), 18, Color("f3d7a0"), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	var gids: Array = Game.s["gear"].keys()
	if gids.is_empty():
		UI.label(self, "No gear yet. Bosses and later zones drop gear.", Vector2(0, 200), 12, Color("c9a77a"), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	var content: Control = UI.scroll(self, Vector2(10, 62), Vector2(300, 366), 52.0 * gids.size())
	for i in range(gids.size()):
		var gid: String = str(gids[i])
		var g: Dictionary = Game.s["gear"][gid]
		var gd: Dictionary = Data.gear[str(g["id"])]
		var y: float = 52.0 * float(i)
		UI.panel(content, Vector2(0, y), Vector2(300, 46), Color(0.1, 0.06, 0.05, 0.9), 5)
		UI.label(content, "%s +%d" % [str(gd["name"]), int(g["level"])], Vector2(10, y + 3), 13, UI.rarity_color(int(gd["rarity"])))
		var bonus: int = int(float(gd["val"]) * (1.0 + 0.2 * float(int(g["level"]))))
		var owner_uid: String = Game.gear_owner(gid)
		UI.label(content, "%s %s +%d   %s" % [str(gd["slot"]), str(gd["stat"]).to_upper(), bonus, "" if owner_uid == "" else "(" + str(Game.fam_def(owner_uid)["name"]) + ")"], Vector2(10, y + 25), 9, Color(1, 1, 1, 0.8))
		var c: int = Game.enhance_cost(gid)
		var label_txt: String = "MAX" if c < 0 else "Enhance %dG" % c
		var enh_cb: Callable = func():
			var r: Dictionary = Game.enhance(gid)
			if bool(r["ok"]):
				Assets.sfx("combine_finish")
				_render()
			else:
				main.toast(str(r["msg"]))
		UI.text_button(content, label_txt, Vector2(196, y + 8), Vector2(96, 30), enh_cb, "red" if c >= 0 else "gray")
	UI.text_button(self, "Back", Vector2(110, 440), Vector2(100, 30), func(): main.go("home"), "black")
