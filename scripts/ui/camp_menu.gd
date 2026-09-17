extends Control
class_name CampMenu

## CampMenu - Ash Camp Sanctuary Hub & Squad Formation

var camp_info_lbl: Label
var squad_vbox: VBoxContainer
var upgrades_vbox: VBoxContainer

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build_ui()
	AudioManager.play_music("camp")

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.05, 0.08, 1.0)
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

	# Top Header
	var top_hbox = HBoxContainer.new()
	vbox.add_child(top_hbox)

	var title_lbl = Label.new()
	title_lbl.text = "ASH CAMP SANCTUARY"
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	top_hbox.add_child(title_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)

	var back_btn = Button.new()
	back_btn.text = "MAIN MENU"
	back_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_confirm")
		GameSession.return_to_main_menu()
	)
	top_hbox.add_child(back_btn)

	# Main Columns Split
	var columns_hbox = HBoxContainer.new()
	columns_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns_hbox.add_theme_constant_override("separation", 30)
	vbox.add_child(columns_hbox)

	# Left Column: Camp Upgrades & Buildings
	var left_panel = PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns_hbox.add_child(left_panel)

	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 14)
	left_panel.add_child(left_vbox)

	var bld_header = Label.new()
	bld_header.text = "CAMP FACILITIES & UPGRADES"
	bld_header.add_theme_font_size_override("font_size", 20)
	bld_header.add_theme_color_override("font_color", Color.GOLD)
	left_vbox.add_child(bld_header)

	upgrades_vbox = VBoxContainer.new()
	upgrades_vbox.add_theme_constant_override("separation", 10)
	left_vbox.add_child(upgrades_vbox)

	# Right Column: Hero Roster & Squad Formations
	var right_panel = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns_hbox.add_child(right_panel)

	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 14)
	right_panel.add_child(right_vbox)

	var roster_header = Label.new()
	roster_header.text = "RESCUED ALLIES & SQUAD SYNERGY"
	roster_header.add_theme_font_size_override("font_size", 20)
	roster_header.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	right_vbox.add_child(roster_header)

	squad_vbox = VBoxContainer.new()
	squad_vbox.add_theme_constant_override("separation", 10)
	right_vbox.add_child(squad_vbox)

	_populate_upgrades()
	_populate_roster()

func _populate_upgrades() -> void:
	for child in upgrades_vbox.get_children():
		child.queue_free()

	for u_id in GameData.camp_upgrades:
		var u_info = GameData.camp_upgrades[u_id]
		var cur_lvl = SaveStore.data["camp"].get(u_id + "_level", 1)
		
		var u_row = HBoxContainer.new()
		var u_lbl = Label.new()
		u_lbl.text = "%s (Lv.%d/%d)\n%s" % [u_info["name"], cur_lvl, u_info["max_level"], u_info["desc"]]
		u_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		u_row.add_child(u_lbl)

		var up_btn = Button.new()
		up_btn.text = "UPGRADE (🪙 %d)" % (u_info["cost"] * cur_lvl)
		up_btn.pressed.connect(func():
			var cost = u_info["cost"] * cur_lvl
			if SaveStore.data["player"]["coins"] >= cost and cur_lvl < u_info["max_level"]:
				SaveStore.add_currency(-cost)
				SaveStore.data["camp"][u_id + "_level"] = cur_lvl + 1
				SaveStore.save_game()
				AudioManager.play_sfx("ui_confirm")
				_populate_upgrades()
		)
		u_row.add_child(up_btn)
		upgrades_vbox.add_child(u_row)

func _populate_roster() -> void:
	for child in squad_vbox.get_children():
		child.queue_free()

	var unlocked = SaveStore.data["roster"]["unlocked"]

	for c_id in GameData.characters:
		var c_info = GameData.characters[c_id]
		var is_unlocked = unlocked.has(c_id)

		var r_row = HBoxContainer.new()
		var r_lbl = Label.new()
		if is_unlocked:
			r_lbl.text = "%s — %s\nSynergy: %s (%s)" % [c_info["name"], c_info["role"], c_info["synergy_title"], c_info["synergy_buff"]]
			r_lbl.add_theme_color_override("font_color", Color.WHITE)
		else:
			r_lbl.text = "%s (LOCKED)\nProgress story campaign to rescue this ally." % c_info["name"]
			r_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		
		r_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r_row.add_child(r_lbl)
		squad_vbox.add_child(r_row)
