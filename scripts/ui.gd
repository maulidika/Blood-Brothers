extends Node
## Small helpers for building the 320x480 interface out of the original sprites.
const W := 320
const H := 480
const RACE_ICON := {1: "paragons", 2: "champions", 3: "highlander", 4: "darklander", 5: "westerners",
	6: "easterners", 7: "ape", 8: "lizardmen", 9: "dwarf", 10: "goblin", 11: "undead"}
const RARITY_COLOR := {1: Color("a8a8a8"), 2: Color("6fcf6f"), 3: Color("5b9bf0"), 4: Color("c070f0"),
	5: Color("f5ae3a"), 6: Color("f2503f")}
var font: Font = null

func _ready() -> void:
	var p := "res://assets/original/font/trb.ttf"
	if ResourceLoader.exists(p):
		font = load(p)

func label(parent: Node, text: String, pos: Vector2, fsize: int = 12, color: Color = Color.WHITE,
		width: float = 0.0, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	if width > 0.0:
		l.custom_minimum_size = Vector2(width, 0)
		l.size = Vector2(width, float(fsize) + 6.0)
	l.horizontal_alignment = align
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func sprite(parent: Node, path: String, pos: Vector2, size: Vector2 = Vector2.ZERO) -> TextureRect:
	var t: Texture2D = Assets.tex(path)
	var r := TextureRect.new()
	r.texture = t
	r.position = pos
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if size != Vector2.ZERO:
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.size = size
	elif t != null:
		r.size = t.get_size()
	parent.add_child(r)
	return r

func panel(parent: Node, pos: Vector2, size: Vector2, color: Color = Color(0, 0, 0, 0.6), radius: int = 6) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.border_color = Color(0.55, 0.40, 0.25, 0.9)
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func tex_button(parent: Node, n_path: String, p_path: String, pos: Vector2, cb: Callable,
		size: Vector2 = Vector2.ZERO) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = Assets.tex(n_path)
	if p_path != "":
		b.texture_pressed = Assets.tex(p_path)
	b.position = pos
	if size != Vector2.ZERO:
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.size = size
	b.pressed.connect(func():
		Assets.sfx("sys_click")
		cb.call())
	parent.add_child(b)
	return b

## Red/gray/black framed text button built from the original button sprites.
func text_button(parent: Node, text: String, pos: Vector2, size: Vector2, cb: Callable, style: String = "red") -> TextureButton:
	var n := "common/ui/button/bt_base_red_n_56.png"
	var p := "common/ui/button/bt_base_red_p_56.png"
	if style == "gray":
		n = "common/ui/button/bt_base_gray_56.png"
		p = n
	elif style == "black":
		n = "common/ui/button/bt_base_black_n.png"
		p = "common/ui/button/bt_base_black_p.png"
	var b := tex_button(parent, n, p, pos, cb, size)
	var fs: int = 13 if size.y >= 30.0 else 10
	var l := label(b, text, Vector2(0, (size.y - float(fs) - 6.0) / 2.0), fs, Color.WHITE, size.x, HORIZONTAL_ALIGNMENT_CENTER)
	l.size.x = size.x
	return b

## Invisible click area (used for list rows).
func hit(parent: Node, pos: Vector2, size: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.flat = true
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		Assets.sfx("sys_click")
		cb.call())
	parent.add_child(b)
	return b

func race_icon(parent: Node, race: int, pos: Vector2, px: float) -> TextureRect:
	var key: String = str(RACE_ICON.get(race, "ape"))
	return sprite(parent, "common/ui/race/icon_race_%s_s.png" % key, pos, Vector2(px, px))

func rarity_color(r: int) -> Color:
	return RARITY_COLOR.get(r, Color.WHITE)

func stars(r: int) -> String:
	return "*".repeat(r)

## Compact card tile for a familiar. `inst` = {id, level, ...}. Original card art was server-side
## (not in the APKs) so the portrait is a race-emblem placeholder inside the original card frame.
func fam_tile(parent: Node, inst: Dictionary, pos: Vector2, size: Vector2) -> Control:
	var d: Dictionary = Data.fams[str(inst["id"])]
	var root := Control.new()
	root.position = pos
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)
	var rar: int = int(d["rarity"])
	panel(root, Vector2.ZERO, size, Color(0.10, 0.07, 0.07, 0.85), 5)
	var strip := ColorRect.new()
	strip.color = rarity_color(rar)
	strip.position = Vector2(0, 0)
	strip.size = Vector2(4, size.y)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(strip)
	race_icon(root, int(d["race"]), Vector2(8, (size.y - 32.0) / 2.0), 32.0)
	label(root, str(d["name"]), Vector2(44, 3), 12, Color.WHITE)
	label(root, "%s  Lv %d" % [stars(rar), int(inst.get("level", 1))], Vector2(44, 21), 10, rarity_color(rar))
	return root

## Scrollable column. Returns the content Control; add rows to it (absolute positions).
func scroll(parent: Node, pos: Vector2, size: Vector2, content_h: float) -> Control:
	var sc := ScrollContainer.new()
	sc.position = pos
	sc.size = size
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var content := Control.new()
	content.custom_minimum_size = Vector2(size.x, maxf(content_h, size.y))
	sc.add_child(content)
	return content

func hp_bar(parent: Node, pos: Vector2, size: Vector2, ratio: float) -> Dictionary:
	sprite(parent, "common/battle/btl_hp_base.png", pos, size)
	var fill := sprite(parent, "common/battle/btl_hp_bar.png", pos + Vector2(2, 3), Vector2(maxf(0.0, (size.x - 4.0) * ratio), size.y - 6.0))
	return {"fill": fill, "full": size.x - 4.0, "h": size.y - 6.0}

func set_hp_bar(bar: Dictionary, ratio: float) -> void:
	var fill: TextureRect = bar["fill"]
	fill.size = Vector2(maxf(0.0, float(bar["full"]) * clampf(ratio, 0.0, 1.0)), float(bar["h"]))

func stat_line(inst_uid: String) -> String:
	return "ATK %d  DEF %d  WIS %d  AGI %d" % [int(Game.fam_stat(inst_uid, "atk")), int(Game.fam_stat(inst_uid, "def")),
		int(Game.fam_stat(inst_uid, "wis")), int(Game.fam_stat(inst_uid, "agi"))]
