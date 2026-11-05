extends Control
## Plays back the event log produced by BattleEngine (the fight is already decided when this opens).
var main
var args: Dictionary = {}
var eng
var stage: Dictionary = {}
var tiles: Dictionary = {}
var speed: float = 1.0
var skip: bool = false
var round_label: Label
var banner: Control
var banner_label: Label
var _alive: bool = true

func _ready() -> void:
	eng = args["engine"]
	stage = args["stage"]
	Assets.play_bgm("bossBattle" if bool(stage["boss"]) else "battle")
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.04, 0.05)
	bg.size = Vector2(UI.W, UI.H)
	add_child(bg)
	UI.sprite(self, "common/battle/battle_blackbackground.png", Vector2(-96, 0), Vector2(512, 181))
	UI.sprite(self, "common/battle/battle_blackbackground.png", Vector2(-96, 299), Vector2(512, 181))
	UI.label(self, str(stage["name"]), Vector2(0, 6), 12, Color("f3d7a0"), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	round_label = UI.label(self, "", Vector2(0, 218), 12, Color.WHITE, UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	for u in eng.units:
		_make_tile(u)
	banner = UI.sprite(self, "common/battle/skill_back.png", Vector2(10, 196), Vector2(300, 26))
	banner.visible = false
	banner_label = UI.label(banner, "", Vector2(0, 3), 13, Color.WHITE, 300, HORIZONTAL_ALIGNMENT_CENTER)
	UI.text_button(self, "Speed x1", Vector2(10, 446), Vector2(90, 26), func(): _toggle_speed(), "gray")
	UI.text_button(self, "Skip", Vector2(220, 446), Vector2(90, 26), func(): skip = true, "black")
	_play()

func _exit_tree() -> void:
	_alive = false

func _tile_pos(u: Dictionary) -> Vector2:
	var line: int = int(u["slot"]) / 2
	var col: int = int(u["slot"]) % 2
	var x: float = 28.0 + float(col) * 140.0
	var y: float = 0.0
	if int(u["side"]) == 1:
		y = 44.0 + float(2 - line) * 50.0
	else:
		y = 244.0 + float(line) * 50.0
	return Vector2(x, y)

func _make_tile(u: Dictionary) -> void:
	var root := Control.new()
	root.position = _tile_pos(u)
	root.size = Vector2(124, 46)
	root.pivot_offset = Vector2(62, 23)
	add_child(root)
	var enemy: bool = int(u["side"]) == 1
	UI.panel(root, Vector2.ZERO, Vector2(124, 46), Color(0.25, 0.05, 0.05, 0.85) if enemy else Color(0.05, 0.1, 0.22, 0.85), 5)
	UI.race_icon(root, int(u["race"]), Vector2(4, 4), 26.0)
	var nm: String = str(u["name"])
	if u.get("is_boss", false):
		nm = "[BOSS] " + nm
	UI.label(root, nm, Vector2(34, 1), 9, UI.rarity_color(int(u["rarity"])))
	UI.label(root, "Lv%d" % int(u["level"]), Vector2(34, 12), 8, Color(1, 1, 1, 0.8))
	var bar: Dictionary = UI.hp_bar(root, Vector2(34, 26), Vector2(84, 16), 1.0)
	tiles[int(u["idx"])] = {"root": root, "bar": bar, "max": float(u["max_hp"])}

func _toggle_speed() -> void:
	speed = 2.0 if speed == 1.0 else 1.0

func _wait(t: float) -> void:
	if skip or not _alive:
		return
	await get_tree().create_timer(t / speed).timeout

func _popup(idx: int, text: String, color: Color) -> void:
	var t: Dictionary = tiles[idx]
	var root: Control = t["root"]
	var l := UI.label(self, text, root.position + Vector2(40, 0), 16, color)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 22.0, 0.5 / speed)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5 / speed)
	tw.tween_callback(l.queue_free)

func _shake(idx: int) -> void:
	if skip:
		return
	var root: Control = tiles[idx]["root"]
	var tw := create_tween()
	tw.tween_property(root, "scale", Vector2(1.08, 1.08), 0.06 / speed)
	tw.tween_property(root, "scale", Vector2.ONE, 0.10 / speed)

func _set_hp(idx: int, hp: float) -> void:
	var t: Dictionary = tiles[idx]
	UI.set_hp_bar(t["bar"], hp / float(t["max"]))

func _play() -> void:
	Assets.sfx("battle_start")
	await _wait(0.7)
	for e in eng.events:
		if not _alive:
			return
		await _handle(e)
	if not _alive:
		return
	await _wait(0.5)
	_finish()

func _handle(e: Dictionary) -> void:
	match str(e["t"]):
		"round":
			round_label.text = "Round %d" % int(e["n"])
			await _wait(0.1)
		"act":
			if bool(e["special"]):
				banner.visible = true
				banner_label.text = str(e["skill"])
				Assets.sfx("skill_power")
				await _wait(0.45)
				banner.visible = false
			else:
				await _wait(0.12)
		"dmg":
			var amt: int = int(e["amount"])
			var dst: int = int(e["dst"])
			_set_hp(dst, float(e["hp"]))
			if str(e["kind"]) == "drain":
				_set_hp(int(e["src"]), float(e["src_hp"]))
			if not skip:
				_popup(dst, str(amt), Color("ff6a5a"))
				_shake(dst)
				if str(e["kind"]) == "magic":
					Assets.sfx("magic_small")
				elif float(amt) > tiles[dst]["max"] * 0.25:
					Assets.sfx("hit_large")
				elif float(amt) > tiles[dst]["max"] * 0.1:
					Assets.sfx("hit_midium")
				else:
					Assets.sfx("hit_small")
			await _wait(0.28)
		"heal":
			_set_hp(int(e["dst"]), float(e["hp"]))
			if not skip:
				_popup(int(e["dst"]), "+%d" % int(e["amount"]), Color("7fe07f"))
				Assets.sfx("skill_cure")
			await _wait(0.28)
		"buff":
			var up: bool = bool(e["up"])
			var st: String = str(e["stat"]).to_upper()
			if not skip:
				_popup(int(e["dst"]), "%s %s" % [st, "UP" if up else "DOWN"], Color("ffd860") if up else Color("a090ff"))
				Assets.sfx("increase_attack" if up else "decrease_attack")
			await _wait(0.22)
		"down":
			var root: Control = tiles[int(e["dst"])]["root"]
			root.modulate = Color(1, 1, 1, 0.3)
			await _wait(0.18)

func _finish() -> void:
	banner.visible = false
	var won: bool = eng.result == "win"
	var res: Dictionary = Game.finish_stage(stage, won)
	Assets.stop_bgm()
	if won:
		Assets.play_bgm("boss_win" if bool(stage["boss"]) else "battle_win")
	else:
		Assets.sfx("battle_lose")
	var box := UI.panel(self, Vector2(20, 90), Vector2(280, 290), Color(0.1, 0.05, 0.05, 0.97), 8)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	UI.label(box, "VICTORY" if won else "DEFEAT", Vector2(0, 8), 24, Color("f3d7a0") if won else Color("e06050"), 280, HORIZONTAL_ALIGNMENT_CENTER)
	var lines: Array = []
	if won:
		lines.append("Gold +%d     Exp +%d (each unit)" % [int(res["gold"]), int(res["exp"])])
		if int(res["rank_ups"]) > 0:
			lines.append("RANK UP!  Now rank %d (+1 blood coin, energy refilled)" % int(Game.s["rank"]))
		for lu in res["level_ups"]:
			lines.append("%s reached Lv %d" % [str(Game.fam_def(str(lu["uid"]))["name"]), int(Game.fam(str(lu["uid"]))["level"])])
		for d in res["drops"]:
			lines.append("Obtained familiar: %s" % str(Data.fams[str(d["fid"])]["name"]))
		if str(res["gear"]) != "":
			lines.append("Obtained gear: %s" % str(Data.gear[str(res["gear"])]["name"]))
		if res.has("blood"):
			lines.append("First boss clear: +%d blood coins" % int(res["blood"]))
	else:
		lines.append("Your brigade was defeated after %d rounds." % int(eng.rounds))
		lines.append("Level up your familiars, combine, evolve or change the formation, then try again.")
	var info := UI.label(box, "\n".join(lines), Vector2(14, 48), 11, Color.WHITE, 252)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size = Vector2(252, 170)
	var zone: Dictionary = Data.zone_of_stage(str(stage["id"]))
	var zi: int = int(zone["order"]) - 1
	var next_stage: Dictionary = {}
	for i in range(zone["stages"].size()):
		if zone["stages"][i]["id"] == stage["id"] and i + 1 < zone["stages"].size():
			next_stage = zone["stages"][i + 1]
	var sid: String = str(stage["id"])
	UI.text_button(box, "Retry", Vector2(14, 246), Vector2(76, 30), func(): _again(sid), "gray")
	if won and not next_stage.is_empty():
		var nid: String = str(next_stage["id"])
		UI.text_button(box, "Next", Vector2(102, 246), Vector2(76, 30), func(): _again(nid))
	UI.text_button(box, "Done", Vector2(190, 246), Vector2(76, 30), func(): main.go("adventure", {"zone": zi}), "black")

func _again(sid: String) -> void:
	var r: Dictionary = Game.begin_stage(sid)
	if not bool(r["ok"]):
		main.toast(str(r["msg"]))
		return
	main.go("battle", {"engine": r["engine"], "stage": r["stage"]})
