extends Node2D
class_name TrainingDojo

## TrainingDojo - Practice Chamber with Dummy AI, Frame Data Display, and Move Testing

var player: Fighter
var dummy: Fighter
var info_label: Label

func _ready() -> void:
	_setup_arena()
	_spawn_fighters()
	_setup_ui()
	AudioManager.play_music("combat")

func _setup_arena() -> void:
	# Floor StaticBody
	var floor_body = StaticBody2D.new()
	floor_body.collision_layer = 1
	var floor_col = CollisionShape2D.new()
	var floor_shape = WorldBoundaryShape2D.new()
	floor_shape.normal = Vector2.UP
	floor_col.shape = floor_shape
	floor_body.position = Vector2(0, 580)
	floor_body.add_child(floor_col)
	add_child(floor_body)

	var camera = Camera2D.new()
	camera.position = Vector2(0, 360)
	add_child(camera)

func _spawn_fighters() -> void:
	player = Fighter.new()
	player.is_player = true
	player.position = Vector2(-150, 580)
	add_child(player)

	dummy = Fighter.new()
	dummy.is_player = false
	dummy.character_id = "TRAINING DUMMY"
	dummy.weapon_id = "fists"
	dummy.max_hp = 9999.0
	dummy.current_hp = 9999.0
	dummy.position = Vector2(150, 580)
	add_child(dummy)

	player.opponent = dummy
	dummy.opponent = player

	player.state_changed.connect(_on_player_state_changed)

func _setup_ui() -> void:
	var canvas = CanvasLayer.new()
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 30)
	canvas.add_child(margin)

	var top_bar = HBoxContainer.new()
	margin.add_child(top_bar)

	info_label = Label.new()
	info_label.text = "TRAINING DOJO\nState: IDLE | Weapon: %s\nControls: A/D Move | W Jump | S Crouch | F Light | K Heavy | G Grab | H Ranged | R Rage" % player.weapon_id.to_upper()
	info_label.add_theme_font_size_override("font_size", 16)
	info_label.add_theme_color_override("font_color", Color.CYAN)
	top_bar.add_child(info_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	var exit_btn = Button.new()
	exit_btn.text = "EXIT DOJO"
	exit_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_confirm")
		GameSession.return_to_main_menu()
	)
	top_bar.add_child(exit_btn)

	add_child(canvas)

func _on_player_state_changed(old_s: String, new_s: String) -> void:
	var move_name = player.current_move.get("name", "None") if new_s == "ATTACK" else "None"
	info_label.text = "TRAINING DOJO\nState: %s (from %s) | Current Attack: %s\nControls: A/D Move | W Jump | S Crouch | F Light | K Heavy | G Grab | H Ranged | R Rage" % [
		new_s, old_s, move_name
	]

func _draw() -> void:
	# Draw Dojo Background
	draw_rect(Rect2(-1000, 0, 2000, 580), Color(0.08, 0.06, 0.05, 1.0))
	# Dojo wooden pillars
	for x in [-600, -300, 0, 300, 600]:
		draw_rect(Rect2(x - 10, 0, 20, 580), Color(0.18, 0.12, 0.08, 0.6))
	# Tatami floor line
	draw_rect(Rect2(-1000, 580, 2000, 200), Color(0.12, 0.10, 0.06, 1.0))
	draw_line(Vector2(-1000, 580), Vector2(1000, 580), Color(0.8, 0.6, 0.2), 3.0)
