extends Control
class_name MainMenu

## MainMenu - Main Hub UI for CHUG: Shadow of Fame

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build_ui()
	AudioManager.play_music("story")

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.03, 0.06, 1.0)
	add_child(bg)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 60)
	add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 60)
	margin.add_child(hbox)

	# Left Column: Title & Navigation
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(480, 0)
	left_vbox.add_theme_constant_override("separation", 18)
	hbox.add_child(left_vbox)

	var title_lbl = Label.new()
	title_lbl.text = "CHUG"
	title_lbl.add_theme_font_size_override("font_size", 54)
	title_lbl.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0))
	left_vbox.add_child(title_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text = "SHADOW OF FAME"
	sub_lbl.add_theme_font_size_override("font_size", 24)
	sub_lbl.add_theme_color_override("font_color", Color(0.9, 0.2, 0.3))
	left_vbox.add_child(sub_lbl)

	var sep = HSeparator.new()
	left_vbox.add_child(sep)

	# Menu Buttons
	var p_data = SaveStore.data["progression"]
	var cur_part = p_data["current_part"]

	var btn_story = _create_menu_button("STORY CAMPAIGN — PART %d / 50" % cur_part, func():
		AudioManager.play_sfx("ui_confirm")
		GameSession.start_story_part(cur_part)
	)
	left_vbox.add_child(btn_story)

	var btn_camp = _create_menu_button("ASH CAMP & SQUAD", func():
		AudioManager.play_sfx("ui_confirm")
		GameSession.open_camp()
	)
	left_vbox.add_child(btn_camp)

	var btn_armory = _create_menu_button("ARMORY & ATTRIBUTES", func():
		AudioManager.play_sfx("ui_confirm")
		GameSession.open_armory()
	)
	left_vbox.add_child(btn_armory)

	var btn_training = _create_menu_button("TRAINING DOJO", func():
		AudioManager.play_sfx("ui_confirm")
		GameSession.start_training()
	)
	left_vbox.add_child(btn_training)

	var btn_survival = _create_menu_button("SURVIVAL ARENA (STREAK: %d)" % p_data["survival_high_score"], func():
		AudioManager.play_sfx("ui_confirm")
		GameSession.launch_combat({
			"opponent": {
				"name": "Drako Survival Challenger",
				"weapon": "katana",
				"hp": 200,
				"atk": 20,
				"ai_tier": 3
			},
			"environment": "Torii Gate Ruins"
		})
	)
	left_vbox.add_child(btn_survival)

	# Right Column: Player Profile Panel
	var right_panel = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.10, 0.85)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.2, 0.5, 0.8, 0.5)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	right_panel.add_theme_stylebox_override("panel", sb)
	hbox.add_child(right_panel)

	var p_margin = MarginContainer.new()
	p_margin.add_theme_constant_override("margin_left", 30)
	p_margin.add_theme_constant_override("margin_right", 30)
	p_margin.add_theme_constant_override("margin_top", 30)
	p_margin.add_theme_constant_override("margin_bottom", 30)
	right_panel.add_child(p_margin)

	var prof_vbox = VBoxContainer.new()
	prof_vbox.add_theme_constant_override("separation", 14)
	p_margin.add_child(prof_vbox)

	var prof_header = Label.new()
	prof_header.text = "FIGHTER PROFILE"
	prof_header.add_theme_font_size_override("font_size", 24)
	prof_header.add_theme_color_override("font_color", Color.GOLD)
	prof_vbox.add_child(prof_header)

	var p = SaveStore.data["player"]
	var stats = SaveStore.get_calculated_stats()
	var eq = SaveStore.data["equipment"]

	var info_text = """
Name: %s
Level: %d  |  XP: %d / %d
Available Stat Points: %d

Coins: 🪙 %d   Gems: 💎 %d
Equipped Weapon: %s (★%d)

Max Health (HP): %d
Attack Power (ATK): %d
Defense Armor (DEF): %d
Speed Rating (SPD): %.1f
Critical Strike: %.1f%% (x%.2f)
Aura Tier: %d
""" % [
		p["name"],
		p["level"],
		p["xp"],
		GameData.get_xp_for_level(p["level"]),
		p["stat_points"],
		p["coins"],
		p["gems"],
		GameData.weapons.get(eq["equipped_weapon"], {}).get("name", "Fists"),
		eq["weapon_stars"].get(eq["equipped_weapon"], 1),
		int(stats["max_hp"]),
		int(stats["atk"]),
		int(stats["def"]),
		stats["spd"],
		stats["crit_chance"] * 100.0,
		stats["crit_mult"],
		stats["aura_tier"]
	]

	var info_lbl = Label.new()
	info_lbl.text = info_text
	info_lbl.add_theme_font_size_override("font_size", 16)
	info_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	prof_vbox.add_child(info_lbl)

func _create_menu_button(text: String, on_press: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 48)
	btn.add_theme_font_size_override("font_size", 17)
	btn.pressed.connect(on_press)
	return btn
