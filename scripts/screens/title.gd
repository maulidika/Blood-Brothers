extends Control
var main
var args: Dictionary = {}

func _ready() -> void:
	Assets.play_bgm("mainTheme")
	UI.sprite(self, "common/pact/bg.png", Vector2.ZERO, Vector2(UI.W, UI.H))
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.size = Vector2(UI.W, UI.H)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var art: TextureRect = UI.sprite(self, "common/signup/character_1.png", Vector2(40, 90), Vector2(180, 370))
	art.modulate = Color(1, 1, 1, 0.9)
	UI.label(self, "BLOOD BROTHERS 2", Vector2(0, 28), 26, Color("f3d7a0"), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(self, "Offline Restoration", Vector2(0, 62), 13, Color("c9a77a"), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	UI.text_button(self, "Continue", Vector2(160, 330), Vector2(140, 40), func(): main.go("home"))
	UI.text_button(self, "New Game", Vector2(160, 378), Vector2(140, 36), _new_game, "gray")
	UI.label(self, "Original game (c) DeNA 2015. Fan restoration for personal use.", Vector2(0, 458), 8, Color(1, 1, 1, 0.6), UI.W, HORIZONTAL_ALIGNMENT_CENTER)

func _new_game() -> void:
	main.confirm("New Game", "This erases your current save and starts over. Continue?", func():
		Game.new_game()
		main.go("opening", {"next": "home"}))
