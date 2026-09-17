extends Control
class_name StoryManager

## StoryManager - Plays dialogue cutscenes with typewriter text, speaker styling, glitch cues, and combat launch.

var current_part_data: Dictionary = {}
var dialogues: Array = []
var dialogue_index: int = 0
var displayed_text: String = ""
var full_text: String = ""
var text_timer: float = 0.0
var is_typing: bool = false
var is_glitching: bool = false

var header_label: Label
var speaker_label: Label
var body_label: Label
var continue_prompt: Label
var glitch_overlay: ColorRect

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build_ui()
	_load_current_story_part()
	AudioManager.play_music("story")

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.03, 0.06, 1.0)
	add_child(bg)

	# Glitch Overlay
	glitch_overlay = ColorRect.new()
	glitch_overlay.set_anchors_preset(PRESET_FULL_RECT)
	glitch_overlay.color = Color(1.0, 0.0, 0.4, 0.0)
	glitch_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(glitch_overlay)

	# Main Margin Container
	var margin = MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	# Header (Act, Chapter, Part)
	header_label = Label.new()
	header_label.add_theme_font_size_override("font_size", 22)
	header_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 0.8))
	vbox.add_child(header_label)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Dialogue Box Frame
	var dialog_panel = PanelContainer.new()
	dialog_panel.custom_minimum_size = Vector2(0, 220)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.2, 0.6, 0.9, 0.6)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	dialog_panel.add_theme_stylebox_override("panel", sb)
	vbox.add_child(dialog_panel)

	var p_margin = MarginContainer.new()
	p_margin.add_theme_constant_override("margin_left", 24)
	p_margin.add_theme_constant_override("margin_right", 24)
	p_margin.add_theme_constant_override("margin_top", 20)
	p_margin.add_theme_constant_override("margin_bottom", 20)
	dialog_panel.add_child(p_margin)

	var dialog_vbox = VBoxContainer.new()
	dialog_vbox.add_theme_constant_override("separation", 10)
	p_margin.add_child(dialog_vbox)

	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size", 24)
	speaker_label.add_theme_color_override("font_color", Color.GOLD)
	dialog_vbox.add_child(speaker_label)

	body_label = Label.new()
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 20)
	body_label.add_theme_color_override("font_color", Color.WHITE)
	dialog_vbox.add_child(body_label)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	dialog_vbox.add_child(btn_hbox)

	var skip_btn = Button.new()
	skip_btn.text = "SKIP TO FIGHT (F)"
	skip_btn.pressed.connect(_launch_battle)
	btn_hbox.add_child(skip_btn)

	var next_btn = Button.new()
	next_btn.text = "NEXT (SPACE / ENTER)"
	next_btn.pressed.connect(_advance_dialogue)
	btn_hbox.add_child(next_btn)

func _load_current_story_part() -> void:
	var part_idx = GameSession.current_story_part - 1
	if part_idx < 0 or part_idx >= GameData.campaign_parts.size():
		part_idx = 0
	
	current_part_data = GameData.campaign_parts[part_idx]
	dialogues = current_part_data.get("dialogues", [])
	dialogue_index = 0
	
	header_label.text = "ACT %d: %s  |  CHAPTER %d: %s  |  PART %d / 50" % [
		current_part_data.get("act", 1),
		current_part_data.get("act_title", ""),
		current_part_data.get("chapter", 1),
		current_part_data.get("chapter_title", ""),
		current_part_data.get("part", 1)
	]
	
	_show_current_beat()

func _show_current_beat() -> void:
	if dialogue_index >= dialogues.size():
		_launch_battle()
		return
	
	var beat = dialogues[dialogue_index]
	var speaker = beat.get("speaker", "CHUG")
	full_text = beat.get("text", "")
	is_glitching = beat.get("glitch", false)
	
	speaker_label.text = speaker
	_style_speaker(speaker)
	
	displayed_text = ""
	body_label.text = ""
	is_typing = true
	text_timer = 0.0

	if is_glitching:
		AudioManager.play_sfx("glitch")
		glitch_overlay.color = Color(1.0, 0.1, 0.4, 0.25)
	else:
		glitch_overlay.color = Color(0, 0, 0, 0)

func _style_speaker(speaker: String) -> void:
	match speaker:
		"CHUG":
			speaker_label.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0))
		"THE GUIDE":
			speaker_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
		"DONATION", "REFLECTION", "SYSTEM":
			speaker_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.4))
		"YASSINE", "TORA", "SOLO", "KNIGHT":
			speaker_label.add_theme_color_override("font_color", Color.GOLD)
		_: # Drakos / Bosses
			speaker_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))

func _process(delta: float) -> void:
	if is_glitching and glitch_overlay.color.a > 0.0:
		glitch_overlay.color.a = max(0.0, glitch_overlay.color.a - delta * 0.8)
	
	if is_typing:
		text_timer += delta * 45.0 # 45 characters per sec
		var char_count = int(text_timer)
		if char_count < full_text.length():
			displayed_text = full_text.substr(0, char_count)
			body_label.text = displayed_text
		else:
			displayed_text = full_text
			body_label.text = full_text
			is_typing = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		_advance_dialogue()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F:
		_launch_battle()

func _advance_dialogue() -> void:
	if is_typing:
		# Complete text instantly
		displayed_text = full_text
		body_label.text = full_text
		is_typing = false
		AudioManager.play_sfx("ui_click")
	else:
		dialogue_index += 1
		AudioManager.play_sfx("ui_click")
		_show_current_beat()

func _launch_battle() -> void:
	AudioManager.play_sfx("ui_confirm")
	GameSession.launch_combat(current_part_data)
