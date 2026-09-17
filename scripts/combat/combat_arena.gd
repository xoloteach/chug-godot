extends Node2D
class_name CombatArena

## CombatArena - Manages arena stage rendering, fighter instances, camera tracking, and match flow.

@export var environment_type: String = "The Void" # The Void, Torii Gate Ruins, Ash Camp Mountains, Broken Line Fortress, War Gate Sunset Arena

var player: Fighter
var enemy: Fighter
var ai_node: AIController
var hud_node: CombatHUD
var camera_node: Camera2D

var round_timer: float = 99.0
var match_over: bool = false
var victory: bool = false
var match_end_timer: float = 0.0

var screen_shake: float = 0.0

func _ready() -> void:
	_setup_camera()
	_spawn_fighters()
	_setup_hud()
	_setup_arena_bounds()
	AudioManager.play_music("combat")

func _setup_camera() -> void:
	camera_node = Camera2D.new()
	camera_node.name = "CombatCamera"
	camera_node.position_smoothing_enabled = true
	camera_node.position_smoothing_speed = 8.0
	camera_node.zoom = Vector2(1.0, 1.0)
	add_child(camera_node)

func _setup_arena_bounds() -> void:
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

	# Left Wall
	var left_wall = StaticBody2D.new()
	var left_col = CollisionShape2D.new()
	var left_shape = WorldBoundaryShape2D.new()
	left_shape.normal = Vector2.RIGHT
	left_col.shape = left_shape
	left_wall.position = Vector2(-750, 0)
	left_wall.add_child(left_col)
	add_child(left_wall)

	# Right Wall
	var right_wall = StaticBody2D.new()
	var right_col = CollisionShape2D.new()
	var right_shape = WorldBoundaryShape2D.new()
	right_shape.normal = Vector2.LEFT
	right_col.shape = right_shape
	right_wall.position = Vector2(750, 0)
	right_wall.add_child(right_col)
	add_child(right_wall)

func _spawn_fighters() -> void:
	# Player
	player = Fighter.new()
	player.name = "PlayerFighter"
	player.is_player = true
	player.position = Vector2(-180, 580)
	add_child(player)

	# Enemy
	enemy = Fighter.new()
	enemy.name = "EnemyFighter"
	enemy.is_player = false
	enemy.position = Vector2(180, 580)
	
	# Load encounter properties if set by session
	var enc = GameSession.active_encounter_data
	if enc.has("opponent"):
		var opp = enc["opponent"]
		enemy.character_id = opp.get("name", "Void Shadow")
		enemy.weapon_id = opp.get("weapon", "fists")
		enemy.max_hp = opp.get("hp", 150.0)
		enemy.current_hp = enemy.max_hp
		enemy.base_atk = opp.get("atk", 12.0)
		enemy.aura_tier = opp.get("ai_tier", 1) - 1
		
		ai_node = AIController.new()
		ai_node.name = "AIController"
		ai_node.ai_tier = opp.get("ai_tier", 1)
		ai_node.fighter = enemy
		enemy.add_child(ai_node)
	else:
		ai_node = AIController.new()
		ai_node.name = "AIController"
		ai_node.fighter = enemy
		enemy.add_child(ai_node)

	if enc.has("environment"):
		environment_type = enc["environment"]

	add_child(enemy)

	player.opponent = enemy
	enemy.opponent = player

	player.fighter_died.connect(_on_player_died)
	enemy.fighter_died.connect(_on_enemy_died)

func _setup_hud() -> void:
	var canvas = CanvasLayer.new()
	hud_node = CombatHUD.new()
	hud_node.init_hud(player, enemy)
	canvas.add_child(hud_node)
	add_child(canvas)
	hud_node.show_announcement("FIGHT!", 1.2)

func _physics_process(delta: float) -> void:
	if not match_over:
		round_timer -= delta
		hud_node.round_time_remaining = max(0.0, round_timer)
		if round_timer <= 0.0:
			_time_over()

	_update_camera(delta)
	queue_redraw()

func _update_camera(delta: float) -> void:
	if player == null or enemy == null:
		return
	
	var mid_point = (player.global_position + enemy.global_position) * 0.5
	mid_point.y = clampf(mid_point.y - 80.0, 200.0, 520.0)
	
	if screen_shake > 0.0:
		screen_shake -= delta * 15.0
		mid_point += Vector2(randf_range(-screen_shake, screen_shake), randf_range(-screen_shake, screen_shake))
	
	camera_node.global_position = camera_node.global_position.lerp(mid_point, 10.0 * delta)
	
	var dist = abs(player.global_position.x - enemy.global_position.x)
	var target_zoom = clampf(1280.0 / (dist + 500.0), 0.75, 1.25)
	camera_node.zoom = camera_node.zoom.lerp(Vector2(target_zoom, target_zoom), 5.0 * delta)

func _on_player_died() -> void:
	if match_over: return
	match_over = true
	victory = false
	hud_node.show_announcement("DEFEAT", 3.0)
	_finish_match_delayed(2.5)

func _on_enemy_died() -> void:
	if match_over: return
	match_over = true
	victory = true
	hud_node.show_announcement("VICTORY!", 3.0)
	_finish_match_delayed(2.5)

func _time_over() -> void:
	match_over = true
	if player.current_hp > enemy.current_hp:
		victory = true
		hud_node.show_announcement("TIME UP - VICTORY!", 3.0)
	else:
		victory = false
		hud_node.show_announcement("TIME UP - DEFEAT", 3.0)
	_finish_match_delayed(2.5)

func _finish_match_delayed(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	GameSession.on_combat_finished(victory, {
		"round_time": 99.0 - round_timer,
		"combo_count": player.combo_count,
		"damage_dealt": player.combo_damage_accum
	})
	
	if GameSession.current_mode == GameSession.GameMode.STORY:
		GameSession.open_camp()
	else:
		GameSession.return_to_main_menu()

# Procedural Background Arena Painting
func _draw() -> void:
	var arena_w = 2000.0
	var arena_h = 1000.0
	
	match environment_type:
		"The Void":
			# Deep dark gradient with distant void stars
			draw_rect(Rect2(-1000, 0, arena_w, 580), Color(0.04, 0.03, 0.08, 1.0))
			draw_circle(Vector2(-300, 200), 120.0, Color(0.12, 0.05, 0.25, 0.4))
			draw_circle(Vector2(400, 150), 80.0, Color(0.05, 0.15, 0.3, 0.3))
		
		"Torii Gate Ruins":
			# Crimson twilight sky with shattered Torii gates
			draw_rect(Rect2(-1000, 0, arena_w, 580), Color(0.15, 0.04, 0.08, 1.0))
			# Torii Pillars in background
			draw_rect(Rect2(-200, 220, 24, 360), Color(0.25, 0.05, 0.05, 0.8))
			draw_rect(Rect2(200, 220, 24, 360), Color(0.25, 0.05, 0.05, 0.8))
			draw_rect(Rect2(-240, 260, 480, 20), Color(0.35, 0.08, 0.08, 0.9))
		
		"Ash Camp Mountains":
			# Midnight blue mountain silhouettes with warm campfire embers
			draw_rect(Rect2(-1000, 0, arena_w, 580), Color(0.06, 0.08, 0.12, 1.0))
			# Mountain Peaks
			draw_polygon(PackedVector2Array([Vector2(-800, 580), Vector2(-300, 180), Vector2(100, 580)]), PackedColorArray([Color(0.1, 0.12, 0.18)]))
			draw_polygon(PackedVector2Array([Vector2(-100, 580), Vector2(400, 220), Vector2(800, 580)]), PackedColorArray([Color(0.08, 0.1, 0.15)]))
		
		"War Gate Sunset Arena":
			# Dramatic sunset fire sky with massive gate towers
			draw_rect(Rect2(-1000, 0, arena_w, 580), Color(0.22, 0.08, 0.02, 1.0))
			draw_rect(Rect2(-450, 100, 80, 480), Color(0.12, 0.05, 0.05, 0.9))
			draw_rect(Rect2(370, 100, 80, 480), Color(0.12, 0.05, 0.05, 0.9))
			draw_rect(Rect2(-480, 160, 960, 40), Color(0.15, 0.06, 0.06, 0.95))
		
		_:
			draw_rect(Rect2(-1000, 0, arena_w, 580), Color(0.05, 0.05, 0.08, 1.0))

	# Arena Floor Line
	draw_rect(Rect2(-1000, 580, arena_w, 400), Color(0.03, 0.03, 0.04, 1.0))
	draw_line(Vector2(-1000, 580), Vector2(1000, 580), Color(0.4, 0.4, 0.45, 1.0), 3.0)
