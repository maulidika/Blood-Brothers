extends Control
## Collection list + detail, Combine (level up with materials), Evolution, Gear equip, Sell.
var main
var args: Dictionary = {}
var view: String = "list"
var sel: String = ""
var picks: Dictionary = {}
var filter: String = ""

func _ready() -> void:
	filter = str(args.get("filter", ""))
	Assets.play_bgm("home")
	_render()

func _clear() -> void:
	for c in get_children():
		c.queue_free()
	UI.sprite(self, "common/ui/background.png", Vector2(-10, 0))

func _render() -> void:
	_clear()
	match view:
		"list": _list()
		"detail": _detail()
		"combine": _combine()
		"evolve": _evolve()
		"gear": _gear()

func _go(v: String) -> void:
	view = v
	picks = {}
	_render()

# ------------------------------------------------------------------ list
func _list() -> void:
	var title: String = "Evolution" if filter == "evolve" else "Familiars"
	UI.label(self, title, Vector2(0, 34), 18, Color("f3d7a0"), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	var ids: Array = []
	for uid in Game.fam_uids_sorted():
		if filter == "evolve" and (Game.evolve_target(uid) == ""):
			continue
		ids.append(uid)
	if ids.is_empty():
		UI.label(self, "No familiars here yet.", Vector2(0, 200), 13, Color("c9a77a"), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	var content: Control = UI.scroll(self, Vector2(10, 62), Vector2(300, 366), 48.0 * ids.size())
	for i in range(ids.size()):
		var uid: String = str(ids[i])
		var y: float = 48.0 * float(i)
		var inst: Dictionary = Game.fam(uid)
		UI.fam_tile(content, inst, Vector2(0, y), Vector2(300, 44))
		var tags: String = ""
		if Game.in_brigade(uid):
			tags += "[B] "
		if Game.evolve_target(uid) != "" and not Game.evolve_copies(uid).is_empty():
			tags += "[EVO] "
		UI.label(content, tags, Vector2(190, y + 4), 10, Color("ffd860"), 106, HORIZONTAL_ALIGNMENT_RIGHT)
		UI.label(content, "ATK %d  DEF %d" % [int(Game.fam_stat(uid, "atk")), int(Game.fam_stat(uid, "def"))], Vector2(150, y + 24), 9, Color(1, 1, 1, 0.75), 146, HORIZONTAL_ALIGNMENT_RIGHT)
		UI.hit(content, Vector2(0, y), Vector2(300, 44), func():
			sel = uid
			_go("detail"))
	UI.text_button(self, "Back", Vector2(110, 440), Vector2(100, 30), func(): main.go("home"), "black")

# ------------------------------------------------------------------ detail
func _detail() -> void:
	if not Game.s["fams"].has(sel):
		_go("list")
		return
	var inst: Dictionary = Game.fam(sel)
	var d: Dictionary = Game.fam_def(sel)
	var rar: int = int(d["rarity"])
	UI.panel(self, Vector2(10, 34), Vector2(300, 142), Color(0.1, 0.06, 0.05, 0.9), 8)
	UI.race_icon(self, int(d["race"]), Vector2(20, 46), 64.0)
	UI.label(self, str(d["name"]), Vector2(96, 40), 17, Color.WHITE)
	UI.label(self, "%s %s   %s" % [UI.stars(rar), Data.rarity_name(rar), Data.race_name(int(d["race"]))], Vector2(96, 64), 11, UI.rarity_color(rar))
	UI.label(self, "Lv %d / %d     Cost %d" % [int(inst["level"]), int(d["max_level"]), int(d["cost"])], Vector2(96, 82), 12, Color.WHITE)
	var need: int = Data.exp_to_next(int(inst["level"]), rar)
	var ratio: float = 1.0 if int(inst["level"]) >= int(d["max_level"]) else float(inst["exp"]) / float(need)
	UI.hp_bar(self, Vector2(96, 102), Vector2(200, 14), ratio)
	UI.label(self, "EXP %d / %d" % [int(inst["exp"]), need] if int(inst["level"]) < int(d["max_level"]) else "MAX LEVEL", Vector2(96, 118), 9, Color(1, 1, 1, 0.8))
	var gb: Dictionary = Game.gear_bonus(sel)
	var rows: Array = [["HP", "hp"], ["ATK", "atk"], ["DEF", "def"], ["WIS", "wis"], ["AGI", "agi"]]
	for i in range(rows.size()):
		var k: String = str(rows[i][1])
		var extra: String = "" if not gb.has(k) else "  (+%d)" % int(gb[k])
		UI.label(self, "%s  %d%s" % [rows[i][0], int(Game.fam_stat(sel, k)), extra], Vector2(20 + (i % 3) * 98, 130 + (i / 3) * 18), 11, Color.WHITE)
	var sk: Dictionary = Data.skills[str(d["skill"])]
	UI.panel(self, Vector2(10, 182), Vector2(300, 66), Color(0.1, 0.06, 0.05, 0.9), 6)
	UI.label(self, "Skill", Vector2(18, 186), 10, Color("c9a77a"))
	var sl := UI.label(self, Data.skill_text(sk), Vector2(18, 200), 11, Color.WHITE, 284)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl.size = Vector2(284, 44)
	var gid: String = str(inst.get("gear", ""))
	var gtext: String = "None"
	if gid != "" and Game.s["gear"].has(gid):
		var g: Dictionary = Game.s["gear"][gid]
		gtext = "%s +%d" % [str(Data.gear[str(g["id"])]["name"]), int(g["level"])]
	UI.label(self, "Gear: %s" % gtext, Vector2(18, 256), 12, Color("c9a77a"))
	var evo: String = Game.evolve_target(sel)
	if evo != "":
		UI.label(self, "Evolves into %s (%d gold + 1 spare copy)" % [str(Data.fams[evo]["name"]), Game.evolve_gold(sel)], Vector2(18, 276), 10, Color("ffd860"))
	else:
		UI.label(self, "Fully evolved", Vector2(18, 276), 10, Color(0.7, 0.7, 0.7))
	UI.text_button(self, "Combine", Vector2(10, 306), Vector2(94, 34), func(): _go("combine"))
	UI.text_button(self, "Evolve", Vector2(113, 306), Vector2(94, 34), func(): _go("evolve"), "red" if evo != "" else "gray")
	UI.text_button(self, "Gear", Vector2(216, 306), Vector2(94, 34), func(): _go("gear"))
	UI.text_button(self, "Sell (%dG)" % Game.sell_price(sel), Vector2(10, 350), Vector2(130, 32), _sell, "gray")
	var in_b: bool = Game.in_brigade(sel)
	var rm_cb: Callable = func():
		if in_b:
			var idx: int = Game.s["brigade"].find(sel)
			Game.set_brigade_slot(idx, "")
			_render()
	UI.text_button(self, "Remove from Brigade" if in_b else "Not in brigade", Vector2(150, 350), Vector2(160, 32), rm_cb, "gray")
	UI.text_button(self, "Back", Vector2(110, 440), Vector2(100, 30), func(): _go("list"), "black")

func _sell() -> void:
	main.confirm("Sell", "Sell %s for %d gold?" % [str(Game.fam_def(sel)["name"]), Game.sell_price(sel)], func():
		var r: Dictionary = Game.sell(sel)
		if bool(r["ok"]):
			Assets.sfx("sell")
			_go("list")
		else:
			main.toast(str(r["msg"])))

# ------------------------------------------------------------------ combine
func _combine() -> void:
	UI.label(self, "Combine: %s Lv%d" % [str(Game.fam_def(sel)["name"]), int(Game.fam(sel)["level"])], Vector2(0, 34), 14, Color("f3d7a0"), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	var mats: Array = []
	for uid in Game.fam_uids_sorted():
		if Game.can_combine_with(sel, str(uid)):
			mats.append(str(uid))
	mats.reverse()
	var content: Control = UI.scroll(self, Vector2(10, 58), Vector2(300, 306), 48.0 * mats.size())
	for i in range(mats.size()):
		var uid: String = str(mats[i])
		var y: float = 48.0 * float(i)
		var t: Control = UI.fam_tile(content, Game.fam(uid), Vector2(0, y), Vector2(300, 44))
		if picks.has(uid):
			t.modulate = Color(1.0, 0.85, 0.5)
			UI.label(content, "SELECTED", Vector2(210, y + 4), 10, Color("ffd860"), 86, HORIZONTAL_ALIGNMENT_RIGHT)
		UI.hit(content, Vector2(0, y), Vector2(300, 44), func():
			if picks.has(uid):
				picks.erase(uid)
			else:
				picks[uid] = true
			_render())
	var chosen: Array = picks.keys()
	UI.label(self, "Cost %d gold   +%d EXP   (%d selected)" % [Game.combine_cost(chosen), Game.combine_exp(chosen), chosen.size()], Vector2(0, 372), 12, Color.WHITE, UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	UI.text_button(self, "Combine!", Vector2(60, 396), Vector2(200, 36), func():
		var r: Dictionary = Game.combine(sel, chosen)
		if bool(r["ok"]):
			Assets.sfx("combine_finish")
			main.toast("+%d EXP%s" % [int(r["exp"]), "  Level up x%d!" % int(r["ups"]) if int(r["ups"]) > 0 else ""])
			_go("detail")
		else:
			main.toast(str(r["msg"])))
	UI.text_button(self, "Back", Vector2(110, 440), Vector2(100, 30), func(): _go("detail"), "black")

# ------------------------------------------------------------------ evolve
func _evolve() -> void:
	var to: String = Game.evolve_target(sel)
	UI.label(self, "Evolution", Vector2(0, 34), 18, Color("f3d7a0"), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	if to == "":
		UI.label(self, "This familiar cannot evolve further.", Vector2(0, 200), 13, Color.WHITE, UI.W, HORIZONTAL_ALIGNMENT_CENTER)
		UI.text_button(self, "Back", Vector2(110, 440), Vector2(100, 30), func(): _go("detail"), "black")
		return
	UI.fam_tile(self, Game.fam(sel), Vector2(10, 66), Vector2(300, 44))
	UI.sprite(self, "common/card/evolution_arrow.png", Vector2(151, 114))
	var preview: Dictionary = {"id": to, "level": int(Game.fam(sel)["level"])}
	UI.fam_tile(self, preview, Vector2(10, 154), Vector2(300, 44))
	var nd: Dictionary = Data.fams[to]
	var od: Dictionary = Game.fam_def(sel)
	UI.label(self, "HP %d>%d  ATK %d>%d  DEF %d>%d  WIS %d>%d  AGI %d>%d" % [int(od["hp"]), int(nd["hp"]), int(od["atk"]), int(nd["atk"]),
		int(od["def"]), int(nd["def"]), int(od["wis"]), int(nd["wis"]), int(od["agi"]), int(nd["agi"])], Vector2(0, 204), 9, Color("c9a77a"), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(self, "New skill: %s\nMax level %d -> %d" % [str(Data.skills[str(nd["skill"])]["name"]), int(od["max_level"]), int(nd["max_level"])], Vector2(0, 220), 11, Color.WHITE, UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	var copies: Array = Game.evolve_copies(sel)
	UI.label(self, "Choose a spare copy to consume  (%d gold)" % Game.evolve_gold(sel), Vector2(0, 256), 11, Color("ffd860"), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	if copies.is_empty():
		UI.label(self, "No spare copy of %s available." % str(od["name"]), Vector2(0, 300), 12, Color(0.9, 0.5, 0.4), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	var content: Control = UI.scroll(self, Vector2(10, 274), Vector2(300, 110), 48.0 * copies.size())
	for i in range(copies.size()):
		var uid: String = str(copies[i])
		var y: float = 48.0 * float(i)
		var t: Control = UI.fam_tile(content, Game.fam(uid), Vector2(0, y), Vector2(300, 44))
		if picks.has(uid):
			t.modulate = Color(1.0, 0.85, 0.5)
		UI.hit(content, Vector2(0, y), Vector2(300, 44), func():
			picks = {uid: true}
			_render())
	UI.text_button(self, "Evolve!", Vector2(60, 394), Vector2(200, 36), func():
		if picks.is_empty():
			main.toast("Select a spare copy first.")
			return
		var r: Dictionary = Game.evolve(sel, str(picks.keys()[0]))
		if bool(r["ok"]):
			Assets.sfx("forge_pact")
			main.info("Evolved!", "%s is now %s." % [str(od["name"]), str(Data.fams[str(r["to"])]["name"])])
			_go("detail")
		else:
			main.toast(str(r["msg"])))
	UI.text_button(self, "Back", Vector2(110, 440), Vector2(100, 30), func(): _go("detail"), "black")

# ------------------------------------------------------------------ gear
func _gear() -> void:
	UI.label(self, "Equip Gear", Vector2(0, 34), 16, Color("f3d7a0"), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	var gids: Array = Game.s["gear"].keys()
	var content: Control = UI.scroll(self, Vector2(10, 58), Vector2(300, 330), 44.0 * gids.size())
	for i in range(gids.size()):
		var gid: String = str(gids[i])
		var g: Dictionary = Game.s["gear"][gid]
		var gd: Dictionary = Data.gear[str(g["id"])]
		var y: float = 44.0 * float(i)
		UI.panel(content, Vector2(0, y), Vector2(300, 40), Color(0.1, 0.06, 0.05, 0.9), 5)
		UI.label(content, "%s +%d" % [str(gd["name"]), int(g["level"])], Vector2(10, y + 3), 12, UI.rarity_color(int(gd["rarity"])))
		var bonus: int = int(float(gd["val"]) * (1.0 + 0.2 * float(int(g["level"]))))
		var owner_uid: String = Game.gear_owner(gid)
		var owner_txt: String = "" if owner_uid == "" else "on %s" % str(Game.fam_def(owner_uid)["name"])
		UI.label(content, "%s +%d   %s" % [str(gd["stat"]).to_upper(), bonus, owner_txt], Vector2(10, y + 21), 9, Color(1, 1, 1, 0.8))
		UI.hit(content, Vector2(0, y), Vector2(300, 40), func():
			Game.equip(sel, gid)
			_go("detail"))
	var un_cb: Callable = func():
		Game.unequip(sel)
		_go("detail")
	UI.text_button(self, "Unequip", Vector2(40, 396), Vector2(110, 32), un_cb, "gray")
	UI.text_button(self, "Back", Vector2(170, 396), Vector2(110, 32), func(): _go("detail"), "black")
