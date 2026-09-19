extends Node3D
## Hero: the auto-exploring wanderer.
##
## The hero idly wanders between random waypoints on the ground plane, adding a
## subtle bob and turn so the (possibly static) low-poly model feels alive.
## The player can optionally nudge the hero: on desktop with WASD/arrows, on
## touch with the virtual joystick. Movement is pure flavor. Currency accrues
## automatically in GameState regardless of where the hero is.

## Half-size of the square the hero is allowed to wander within (world units).
@export var roam_radius: float = 16.0
## How close counts as "arrived" at a waypoint.
@export var arrive_dist: float = 1.2
## Base walking speed in units/sec (scaled by GameState.travel_speed).
@export var base_speed: float = 3.5
## How fast the hero turns toward its heading (radians/sec-ish via lerp).
@export var turn_rate: float = 6.0

var _waypoint: Vector3 = Vector3.ZERO
var _bob_time: float = 0.0
var _model: Node3D
var _base_model_y: float = 0.0

# Player input direction in world XZ (from InputController). Zero means idle AI.
var player_dir: Vector2 = Vector2.ZERO


func _ready() -> void:
	randomize()
	_model = get_node_or_null("Model")
	if _model != null:
		_base_model_y = _model.position.y
	_pick_new_waypoint()


func _process(delta: float) -> void:
	var speed := base_speed
	if Engine.has_singleton("GameState") == false and has_node("/root/GameState"):
		speed = base_speed * maxf(0.5, get_node("/root/GameState").travel_speed)

	var move_dir := Vector3.ZERO

	if player_dir.length() > 0.05:
		# Player-driven movement takes over the idle loop for the moment.
		move_dir = Vector3(player_dir.x, 0.0, player_dir.y)
		# Re-seed a waypoint near the player's heading so idle resumes smoothly.
		_waypoint = global_position + move_dir.normalized() * 4.0
	else:
		# Idle exploration: steer toward the current waypoint.
		var to_wp := _waypoint - global_position
		to_wp.y = 0.0
		if to_wp.length() <= arrive_dist:
			_pick_new_waypoint()
		else:
			move_dir = to_wp

	if move_dir.length() > 0.001:
		var flat := Vector3(move_dir.x, 0.0, move_dir.z).normalized()
		global_position += flat * speed * delta
		_clamp_to_roam()
		_face_direction(flat, delta)
		# Walk bob.
		_bob_time += delta * speed * 2.0
		if _model != null:
			_model.position.y = _base_model_y + absf(sin(_bob_time)) * 0.12
	else:
		# Gentle idle sway when standing still.
		_bob_time += delta
		if _model != null:
			_model.position.y = _base_model_y + sin(_bob_time * 1.5) * 0.03


func _pick_new_waypoint() -> void:
	_waypoint = Vector3(
		randf_range(-roam_radius, roam_radius),
		0.0,
		randf_range(-roam_radius, roam_radius)
	)


func _clamp_to_roam() -> void:
	global_position.x = clampf(global_position.x, -roam_radius, roam_radius)
	global_position.z = clampf(global_position.z, -roam_radius, roam_radius)


func _face_direction(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.001:
		return
	var target_yaw := atan2(dir.x, dir.z)
	var current := rotation.y
	rotation.y = lerp_angle(current, target_yaw, clampf(turn_rate * delta, 0.0, 1.0))


## Called by InputController each frame with a normalized XZ direction.
func set_player_direction(dir: Vector2) -> void:
	player_dir = dir
