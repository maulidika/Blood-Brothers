extends Control
var main
var args: Dictionary = {}

func _ready() -> void:
	Assets.play_bgm("home")
	UI.sprite(self, "common/ui/background.png", Vector2(-10, 0))
	UI.sprite(self, "common/ui/bottom_red_bg.png", Vector2(0, 328))
	UI.label(self, str(Game.s.get("name", "Wanderer")), Vector2(10, 32), 12, Color("f3d7a0"))
	UI.tex_button(self, "home/btn_home_adventure_n.png", "home/btn_home_adventure_p.png", Vector2(44, 52), func(): main.go("adventure"))
	UI.tex_button(self, "home/btn_home_pact_n.png", "home/btn_home_pact_p.png", Vector2(44, 140), func(): main.go("pact"))
	UI.tex_button(self, "home/btn_home_bloodbrothers_n.png", "home/btn_home_bloodbrothers_p.png", Vector2(44, 228), func(): main.go("brigade"))
	UI.tex_button(self, "home/btn_home_more_n.png", "home/btn_home_more_p.png", Vector2(44, 316), func(): main.go("more"))
	var sz := Vector2(96, 77)
	UI.tex_button(self, "home/home_bottom_btn_evolution_n.png", "home/home_bottom_btn_evolution_p.png", Vector2(8, 394), func(): main.go("familiars", {"filter": "evolve"}), sz)
	UI.tex_button(self, "home/home_bottom_btn_bazaar_n.png", "home/home_bottom_btn_bazaar_p.png", Vector2(112, 394), func(): main.go("gear"), sz)
	UI.tex_button(self, "home/home_bottom_btn_pvp_n.png", "home/home_bottom_btn_pvp_p.png", Vector2(216, 394), func(): main.toast("Arena (PvP) needs servers - offline AI arena comes in the next milestone."), sz)
	if Game.claim_daily():
		main.info("Daily Bonus", "Welcome back! +500 gold, +1 blood coin and full energy.")

