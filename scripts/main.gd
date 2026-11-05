extends Control
## Root: screen router, status header, fade transition, toast and modal dialogs.
const SCREENS := {
	"title": preload("res://scripts/screens/title.gd"),
	"home": preload("res://scripts/screens/home.gd"),
	"adventure": preload("res://scripts/screens/adventure.gd"),
	"battle": preload("res://scripts/screens/battle.gd"),
	"familiars": preload("res://scripts/screens/familiars.gd"),
	"brigade": preload("res://scripts/screens/brigade.gd"),
	"pact": preload("res://scripts/screens/pact.gd"),
	"gear": preload("res://scripts/screens/gear.gd"),
	"more": preload("res://scripts/screens/more.gd"),
}
var current: Control = null
var screen_layer: Control
var header: Control
var header_label: Label
var header_energy: Label
var fade: ColorRect
var toast_panel: Control
var toast_label: Label
var modal_layer: Control
var _busy: bool = false
var _tick: float = 0.0

func _ready() -> void:
	size = Vector2(UI.W, UI.H)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.03)
	bg.size = size
	add_child(bg)
	screen_layer = Control.new()
	screen_layer.size = size
	add_child(screen_layer)
	_build_header()
	modal_layer = Control.new()
	modal_layer.size = size
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_layer)
	toast_panel = UI.panel(self, Vector2(30, 410), Vector2(260, 30), Color(0, 0, 0, 0.85), 8)
	toast_label = UI.label(toast_panel, "", Vector2(0, 5), 12, Color.WHITE, 260, HORIZONTAL_ALIGNMENT_CENTER)
	toast_panel.visible = false
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.size = size
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	Game.changed.connect(_refresh_header)
	go("title")

func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 1.0:
		_tick = 0.0
		Game.refresh_energy()
		_refresh_header()

func _build_header() -> void:
	header = Control.new()
	header.size = Vector2(UI.W, 28)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)
	UI.panel(header, Vector2(0, 0), Vector2(UI.W, 28), Color(0.08, 0.03, 0.03, 0.92), 0)
	header_label = UI.label(header, "", Vector2(6, 5), 11, Color("f3d7a0"))
	header_energy = UI.label(header, "", Vector2(150, 5), 11, Color("9fe0a0"), 164, HORIZONTAL_ALIGNMENT_RIGHT)
	header.visible = false

func _refresh_header() -> void:
	if Game.s.is_empty() or header_label == null:
		return
	header_label.text = "Rank %d   G %d   B %d" % [int(Game.s["rank"]), int(Game.s["gold"]), int(Game.s["blood"])]
	var t: int = Game.seconds_to_next_energy()
	var tt: String = "" if t == 0 else "  (%d:%02d)" % [t / 60, t % 60]
	header_energy.text = "EN %d/%d%s" % [int(Game.s["energy"]), Game.max_energy(), tt]

func go(name: String, args: Dictionary = {}) -> void:
	if _busy:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.12)
	await tw.finished
	if current != null:
		current.queue_free()
		current = null
	for c in modal_layer.get_children():
		c.queue_free()
	var scr: Control = SCREENS[name].new()
	scr.set("main", self)
	scr.set("args", args)
	scr.size = Vector2(UI.W, UI.H)
	screen_layer.add_child(scr)
	current = scr
	header.visible = not (name == "title" or name == "battle")
	_refresh_header()
	var tw2 := create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.18)
	await tw2.finished
	_busy = false

func toast(msg: String) -> void:
	toast_label.text = msg
	toast_panel.visible = true
	toast_panel.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(toast_panel, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): toast_panel.visible = false)

func close_modal() -> void:
	for c in modal_layer.get_children():
		c.queue_free()

## Generic modal. buttons = [{"text": "OK", "cb": Callable, "style": "red"}]; each button also closes the modal.
func dialog(title: String, body: String, buttons: Array, height: float = 170.0) -> Control:
	close_modal()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = size
	modal_layer.add_child(dim)
	var y: float = (UI.H - height) / 2.0
	var box := UI.panel(modal_layer, Vector2(20, y), Vector2(280, height), Color(0.12, 0.07, 0.06, 0.98), 8)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	UI.label(box, title, Vector2(0, 8), 15, Color("f3d7a0"), 280, HORIZONTAL_ALIGNMENT_CENTER)
	var bl := UI.label(box, body, Vector2(14, 34), 11, Color.WHITE, 252)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.size = Vector2(252, height - 80)
	var n: int = buttons.size()
	var bw: float = minf(110.0, (260.0 - 10.0 * float(n - 1)) / float(maxi(n, 1)))
	var x0: float = (280.0 - (bw * float(n) + 10.0 * float(n - 1))) / 2.0
	for i in range(n):
		var b: Dictionary = buttons[i]
		var cb: Callable = b.get("cb", Callable())
		var handler: Callable = func():
			close_modal()
			if cb.is_valid():
				cb.call()
		UI.text_button(box, str(b["text"]), Vector2(x0 + float(i) * (bw + 10.0), height - 42.0), Vector2(bw, 32),
			handler, str(b.get("style", "red")))
	return box

func info(title: String, body: String) -> void:
	dialog(title, body, [{"text": "OK"}])

func confirm(title: String, body: String, on_yes: Callable) -> void:
	dialog(title, body, [{"text": "Cancel", "style": "gray"}, {"text": "OK", "cb": on_yes}])
