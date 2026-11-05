extends Control
## Plays the two original opening movies in order (client: PrologueScene/OpeningMovie, opening_01 then opening_02).
## Tap to skip. If the converted videos are missing or cannot be decoded the screen continues immediately.
var main
var args: Dictionary = {}
const MOVIES := ["opening_01", "opening_02"]
var player: VideoStreamPlayer
var index: int = 0
var finished_all: bool = false

func _ready() -> void:
	Assets.stop_bgm()
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(UI.W, UI.H)
	add_child(bg)
	player = VideoStreamPlayer.new()
	player.size = Vector2(UI.W, UI.H)
	player.expand = true
	player.finished.connect(_on_finished)
	add_child(player)
	var skip := Button.new()
	skip.flat = true
	skip.size = Vector2(UI.W, UI.H)
	skip.focus_mode = Control.FOCUS_NONE
	skip.pressed.connect(_finish)
	add_child(skip)
	UI.label(self, "Tap to skip", Vector2(0, 458), 10, Color(1, 1, 1, 0.5), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	_play(0)

func _play(i: int) -> void:
	if i >= MOVIES.size():
		_finish()
		return
	var s: VideoStream = Assets.video(MOVIES[i])
	if s == null:
		_finish()
		return
	index = i
	player.stream = s
	player.play()

func _on_finished() -> void:
	_play(index + 1)

func _finish() -> void:
	if finished_all:
		return
	finished_all = true
	if player != null:
		player.stop()
	main.go(str(args.get("next", "home")))
