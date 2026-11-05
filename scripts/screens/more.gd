extends Control
var main
var args: Dictionary = {}

func _ready() -> void:
	UI.sprite(self, "common/ui/background.png", Vector2(-10, 0))
	UI.label(self, "More", Vector2(0, 38), 20, Color("f3d7a0"), UI.W, HORIZONTAL_ALIGNMENT_CENTER)
	var y: float = 80.0
	UI.text_button(self, "Familiar Collection", Vector2(60, y), Vector2(200, 38), func(): main.go("familiars")); y += 48
	UI.text_button(self, "Gear & Bazaar", Vector2(60, y), Vector2(200, 38), func(): main.go("gear")); y += 48
	UI.text_button(self, "Music: %s" % ("ON" if Assets.music_on else "OFF"), Vector2(60, y), Vector2(200, 38), _toggle_music, "gray")
	y += 48
	UI.text_button(self, "Sound: %s" % ("ON" if Assets.sfx_on else "OFF"), Vector2(60, y), Vector2(200, 38), _toggle_sfx, "gray")
	y += 48
	UI.text_button(self, "Stats", Vector2(60, y), Vector2(200, 38), _stats, "gray")
	y += 48
	UI.text_button(self, "Watch Opening", Vector2(60, y), Vector2(200, 38), func(): main.go("opening", {"next": "more"}), "gray")
	y += 48
	UI.text_button(self, "Back", Vector2(100, 430), Vector2(120, 34), func(): main.go("home"), "black")

func _stats() -> void:
	var st: Dictionary = Game.s["stats"]
	main.info("Stats", "Battles: %d\nWins: %d\nPacts forged: %d\nFamiliars owned: %d\nStages cleared: %d" % [
		int(st["battles"]), int(st["wins"]), int(st["pacts"]), Game.s["fams"].size(), Game.s["cleared"].size()])

func _toggle_music() -> void:
	Assets.set_music(not Assets.music_on)
	main.go("more")

func _toggle_sfx() -> void:
	Assets.sfx_on = not Assets.sfx_on
	main.go("more")
