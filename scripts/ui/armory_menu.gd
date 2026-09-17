extends Control
class_name ArmoryMenu

## ArmoryMenu - Gear Equip, Weapon Purchasing/Upgrading, and Attribute Allocation

var stat_points_lbl: Label
var stats_summary_lbl: Label
var weapon_list_vbox: VBoxContainer

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.04, 0.07, 1.0)
	add_child(bg)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	# Top Bar
	var top_hbox = HBoxContainer.new()
	vbox.add_child(top_hbox)

	var title_lbl = Label.new()
	title_lbl.text = "MASTER ARMORY & ATTRIBUTES"
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color.GOLD)
	top_hbox.add_child(title_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)

	var wallet_lbl = Label.new()
	var p = SaveStore.data["player"]
	wallet_lbl.text = "🪙 Coins: %d   💎 Gems: %d" % [p["coins"], p["gems"]]
	wallet_lbl.add_theme_font_size_override("font_size", 20)
	top_hbox.add_child(wallet_lbl)

	var back_btn = Button.new()
	back_btn.text = "BACK TO MENU"
	back_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_confirm")
		GameSession.return_to_main_menu()
	)
	top_hbox.add_child(back_btn)

	var main_split = HBoxContainer.new()
	main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_split.add_theme_constant_override("separation", 30)
	vbox.add_child(main_split)

	# Left: Attribute Allocation & Stats
	var attr_panel = PanelContainer.new()
	attr_panel.custom_minimum_size = Vector2(400, 0)
	main_split.add_child(attr_panel)

	var attr_vbox = VBoxContainer.new()
	attr_vbox.add_theme_constant_override("separation", 12)
	attr_panel.add_child(attr_vbox)

	var attr_title = Label.new()
	attr_title.text = "STAT POINT ALLOCATION"
	attr_title.add_theme_font_size_override("font_size", 20)
	attr_title.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	attr_vbox.add_child(attr_title)

	stat_points_lbl = Label.new()
	stat_points_lbl.text = "Available Points: %d" % p["stat_points"]
	stat_points_lbl.add_theme_font_size_override("font_size", 16)
	attr_vbox.add_child(stat_points_lbl)

	# 5 Core Attributes
	var stat_keys = [
		{"key": "hp", "name": "Health (HP +15)"},
		{"key": "atk", "name": "Attack (ATK +1.5)"},
		{"key": "def", "name": "Defense (DEF +1)"},
		{"key": "spd", "name": "Speed (SPD +0.15)"},
		{"key": "crit", "name": "Critical (+1.25%)"}
	]

	for s_info in stat_keys:
		var s_row = HBoxContainer.new()
		var s_lbl = Label.new()
		s_lbl.text = "%s: %d" % [s_info["name"], p["allocated_" + s_info["key"]]]
		s_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_row.add_child(s_lbl)

		var plus_btn = Button.new()
		plus_btn.text = "+1"
		plus_btn.pressed.connect(func():
			if SaveStore.allocate_stat(s_info["key"]):
				AudioManager.play_sfx("ui_click")
				_refresh_ui()
		)
		s_row.add_child(plus_btn)
		attr_vbox.add_child(s_row)

	var stat_sep = HSeparator.new()
	attr_vbox.add_child(stat_sep)

	stats_summary_lbl = Label.new()
	stats_summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	attr_vbox.add_child(stats_summary_lbl)

	# Right: Weapon Catalog Scroll
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_split.add_child(scroll)

	weapon_list_vbox = VBoxContainer.new()
	weapon_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_list_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(weapon_list_vbox)

	_populate_weapons()
	_update_stats_summary()

func _populate_weapons() -> void:
	for child in weapon_list_vbox.get_children():
		child.queue_free()

	var inv = SaveStore.data["inventory"]["weapons"]
	var eq_wpn = SaveStore.data["equipment"]["equipped_weapon"]

	for w_id in GameData.weapons:
		var w_info = GameData.weapons[w_id]
		var is_unlocked = inv.has(w_id)
		var is_equipped = (w_id == eq_wpn)
		var stars = SaveStore.data["equipment"]["weapon_stars"].get(w_id, 1)

		var w_panel = PanelContainer.new()
		var p_hbox = HBoxContainer.new()
		p_hbox.add_theme_constant_override("separation", 16)
		w_panel.add_child(p_hbox)

		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p_hbox.add_child(info_vbox)

		var name_lbl = Label.new()
		name_lbl.text = "%s (★%d) — %s" % [w_info["name"], stars, w_info["category"]]
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.add_theme_color_override("font_color", Color.GOLD if is_equipped else Color.WHITE)
		info_vbox.add_child(name_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = "ATK +%d | SPD x%.2f — %s" % [w_info["atk_bonus"], w_info["speed_bonus"], w_info["desc"]]
		desc_lbl.add_theme_font_size_override("font_size", 14)
		desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		info_vbox.add_child(desc_lbl)

		# Action Button
		if is_equipped:
			var eq_badge = Label.new()
			eq_badge.text = "[EQUIPPED]"
			eq_badge.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
			p_hbox.add_child(eq_badge)
		elif is_unlocked:
			var eq_btn = Button.new()
			eq_btn.text = "EQUIP"
			eq_btn.pressed.connect(func():
				SaveStore.equip_weapon(w_id)
				AudioManager.play_sfx("ui_confirm")
				_refresh_ui()
			)
			p_hbox.add_child(eq_btn)
		else:
			var buy_btn = Button.new()
			buy_btn.text = "BUY (🪙 %d)" % w_info["price"]
			buy_btn.pressed.connect(func():
				if SaveStore.data["player"]["coins"] >= w_info["price"]:
					SaveStore.add_currency(-w_info["price"])
					SaveStore.unlock_weapon(w_id)
					SaveStore.equip_weapon(w_id)
					AudioManager.play_sfx("ui_confirm")
					_refresh_ui()
			)
			p_hbox.add_child(buy_btn)

		weapon_list_vbox.add_child(w_panel)

func _update_stats_summary() -> void:
	var s = SaveStore.get_calculated_stats()
	stats_summary_lbl.text = """
Calculated Combat Power:
• Max Health: %d HP
• Attack Power: %d ATK
• Flat Defense: %d DEF
• Armor Mitigation: %.1f%%
• Move Speed: %.1f
• Critical Rate: %.1f%% (x%.2f)
• Aura Tier: %d
""" % [
		int(s["max_hp"]),
		int(s["atk"]),
		int(s["def"]),
		s["def_mitigation"] * 100.0,
		s["spd"],
		s["crit_chance"] * 100.0,
		s["crit_mult"],
		s["aura_tier"]
	]

func _refresh_ui() -> void:
	stat_points_lbl.text = "Available Points: %d" % SaveStore.data["player"]["stat_points"]
	_update_stats_summary()
	_populate_weapons()
