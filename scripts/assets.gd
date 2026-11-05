extends Node
## Loads the ORIGINAL sprites/audio extracted by tools/extract_assets.py.
const UI_ROOT := "res://assets/original/ui/"
const AUDIO_ROOT := "res://assets/original/audio/common/audio/"
## Part 8 extraction (byte-exact standalone textures, converted video, imagefont). Kept separate from assets/original.
const V2_IMAGE_ROOT := "res://assets/extracted_v2/images/"
const V2_MOVIE_ROOT := "res://assets/extracted_v2/movie/"
const V2_FONT_ROOT := "res://assets/extracted_v2/imagefont/high/"

var audio_map: Dictionary = {}
var music_on: bool = true
var sfx_on: bool = true
var _tex_cache: Dictionary = {}
var _bgm_player: AudioStreamPlayer
var _sfx_players: Array = []
var _sfx_next: int = 0
var _current_bgm: String = ""

func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	add_child(_bgm_player)
	for i in range(6):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	var f := FileAccess.open("res://data/audio_map.json", FileAccess.READ)
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			audio_map = parsed

## Returns the sprite at <UI_ROOT>/<path>, or null if it was not extracted.
func tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var full: String = UI_ROOT + path
	var t: Texture2D = null
	if ResourceLoader.exists(full):
		t = load(full)
	elif ResourceLoader.exists(V2_IMAGE_ROOT + path):      # standalone textures that are not part of any sprite sheet
		t = load(V2_IMAGE_ROOT + path)
	_tex_cache[path] = t
	return t

func play_bgm(name: String) -> void:
	if name == _current_bgm and _bgm_player.playing:
		return
	_current_bgm = name
	if not music_on:
		_bgm_player.stop()
		return
	var id: String = str(audio_map.get("bgm", {}).get(name, ""))
	if id == "":
		return
	var path: String = AUDIO_ROOT + "bgm/" + id + ".ogg"
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	_bgm_player.stream = stream
	_bgm_player.play()

func stop_bgm() -> void:
	_current_bgm = ""
	_bgm_player.stop()

func set_music(on: bool) -> void:
	music_on = on
	if on:
		var n: String = _current_bgm
		_current_bgm = ""
		play_bgm(n if n != "" else "home")
	else:
		_bgm_player.stop()

func sfx(name: String) -> void:
	if not sfx_on:
		return
	var id: String = str(audio_map.get("sfx", {}).get(name, ""))
	if id == "":
		return
	var path: String = AUDIO_ROOT + "ogg/" + id + ".ogg"
	if not ResourceLoader.exists(path):
		return
	var p: AudioStreamPlayer = _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	p.stream = load(path)
	p.play()

var _imagefonts: Dictionary = {}

## Opening movies (converted to Ogg Theora, the only video format Godot 4 plays natively). null if unavailable.
func video(name: String) -> VideoStream:
	var p: String = V2_MOVIE_ROOT + name + ".ogv"
	if ResourceLoader.exists(p):
		var s = load(p)
		if s is VideoStream:
			return s
	return null

## Original bitmap font ("imagefont": styles blackframe / cutin / white). Returns {} if not extracted.
func imagefont(style: String) -> Dictionary:
	if _imagefonts.has(style):
		return _imagefonts[style]
	var out: Dictionary = {}
	var base: String = V2_FONT_ROOT + style + "/"
	if ResourceLoader.exists(base + "imagefont.png") and FileAccess.file_exists(base + "glyphs.json"):
		var f := FileAccess.open(base + "glyphs.json", FileAccess.READ)
		var j = JSON.parse_string(f.get_as_text())
		if typeof(j) == TYPE_DICTIONARY and j.has("glyphs"):
			var glyphs: Dictionary = {}
			for g in j["glyphs"]:
				glyphs[int(g["code"])] = g
			out = {"atlas": load(base + "imagefont.png"), "glyphs": glyphs}
	_imagefonts[style] = out
	return out
