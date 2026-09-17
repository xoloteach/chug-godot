extends CharacterBody2D
class_name Fighter

## Fighter - Core 2D fighting entity for Player and Enemy combatants
## Implements 60Hz deterministic physics, frame-data state machine, combo strings, and silhouette visuals.

signal health_changed(current_hp: float, max_hp: float)
signal rage_changed(current_rage: float, max_rage: float, tier: int)
signal state_changed(old_state: String, new_state: String)
signal combo_updated(hits: int, total_damage: float)
signal fighter_died

enum State {
	IDLE,
	WALK_FWD,
	WALK_BWD,
	JUMP,
	FALL,
	CROUCH,
	ATTACK,
	BLOCK,
	PARRY,
	HURT,
	LAUNCHED,
	KNOCKDOWN,
	GETUP,
	CLINCH,
	RAGE_BURST,
	DEAD
}

@export var is_player: bool = true
@export var character_id: String = "chug"
@export var weapon_id: String = "fists"

# Stats
var max_hp: float = 150.0
var current_hp: float = 150.0
var base_atk: float = 10.0
var def_flat: float = 0.0
var def_mitigation: float = 0.0
var move_speed: float = 240.0
var crit_chance: float = 0.05
var crit_mult: float = 1.50
var aura_tier: int = 0

# Rage System
var max_rage: float = 100.0
var current_rage: float = 0.0
var is_in_rage_mode: bool = false
var rage_timer: float = 0.0

# Combat & Frame Timing
var current_state: State = State.IDLE
var state_time: float = 0.0
var facing_direction: int = 1 # 1 = Right, -1 = Left
var hitstop_timer: float = 0.0
var parry_window_timer: float = 0.0
var combo_count: int = 0
var combo_damage_accum: float = 0.0
var combo_reset_timer: float = 0.0

# Current Attack Properties
var current_move: Dictionary = {}
var move_phase: String = "startup" # startup, active, recovery
var move_frame: int = 0
var combo_string: Array[String] = []

# Nodes & Collision
var hurtbox_area: Area2D
var hitbox_node: Hitbox
var opponent: Fighter = null

# Input Buffer
var input_buffer: Array[String] = []
var buffer_window: float = 0.25
var buffer_timer: float = 0.0

# Animation / Visual variables
var anim_timer: float = 0.0
var flash_timer: float = 0.0
var body_tilt: float = 0.0
var arm_swing_angle: float = 0.0
var leg_swing_angle: float = 0.0
var weapon_swing_progress: float = 0.0

const GRAVITY: float = 1800.0
const JUMP_VELOCITY: float = -650.0

func _ready() -> void:
	_init_stats()
	_setup_colliders()
	_setup_hurtbox_hitbox()

func _init_stats() -> void:
	if is_player:
		var s = SaveStore.get_calculated_stats()
		max_hp = s["max_hp"]
		current_hp = max_hp
		base_atk = s["atk"]
		def_flat = s["def"]
		def_mitigation = s["def_mitigation"]
		move_speed = 220.0 + (s["spd"] * 10.0)
		crit_chance = s["crit_chance"]
		crit_mult = s["crit_mult"]
		aura_tier = s["aura_tier"]
		weapon_id = SaveStore.data["equipment"]["equipped_weapon"]
	else:
		# Enemy initialized dynamically by Arena
		pass
	
	current_hp = max_hp
	current_rage = 0.0

func _setup_colliders() -> void:
	collision_layer = 1
	collision_mask = 1
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(36, 110)
	col.shape = rect
	col.position = Vector2(0, -55)
	add_child(col)

func _setup_hurtbox_hitbox() -> void:
	# Hurtbox Area
	hurtbox_area = Area2D.new()
	hurtbox_area.name = "Hurtbox"
	hurtbox_area.add_to_group("hurtbox")
	hurtbox_area.collision_layer = 2
	hurtbox_area.collision_mask = 2
	var h_col = CollisionShape2D.new()
	var h_rect = RectangleShape2D.new()
	h_rect.size = Vector2(40, 115)
	h_col.shape = h_rect
	h_col.position = Vector2(0, -57)
	hurtbox_area.add_child(h_col)
	add_child(hurtbox_area)

	# Hitbox Node
	hitbox_node = Hitbox.new()
	hitbox_node.name = "ActiveHitbox"
	hitbox_node.attacker = self
	hitbox_node.collision_layer = 2
	hitbox_node.collision_mask = 2
	var hit_col = CollisionShape2D.new()
	var hit_rect = RectangleShape2D.new()
	hit_rect.size = Vector2(50, 40)
	hit_col.shape = hit_rect
	hit_col.position = Vector2(35, -60)
	hitbox_node.add_child(hit_col)
	hitbox_node.monitoring = false
	add_child(hitbox_node)

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		_process_gravity(delta)
		move_and_slide()
		queue_redraw()
		return
	
	if hitstop_timer > 0.0:
		hitstop_timer -= delta
		queue_redraw()
		return

	_update_facing()
	_process_state(delta)
	_process_gravity(delta)
	_process_timers(delta)
	move_and_slide()
	queue_redraw()

func _update_facing() -> void:
	if opponent != null and current_state != State.ATTACK and current_state != State.HURT and current_state != State.LAUNCHED:
		var target_face = 1 if opponent.global_position.x >= global_position.x else -1
		if target_face != facing_direction:
			facing_direction = target_face

func _process_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif velocity.y > 0:
		velocity.y = 0.0

func _process_timers(delta: float) -> void:
	state_time += delta
	anim_timer += delta * (move_speed / 200.0)
	
	if flash_timer > 0.0:
		flash_timer -= delta
	
	if parry_window_timer > 0.0:
		parry_window_timer -= delta
	
	if combo_reset_timer > 0.0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0.0 and combo_count > 0:
			combo_count = 0
			combo_damage_accum = 0.0
			combo_updated.emit(0, 0.0)

	if is_in_rage_mode:
		rage_timer -= delta
		current_rage = clampf((rage_timer / 10.0) * max_rage, 0.0, max_rage)
		rage_changed.emit(current_rage, max_rage, aura_tier)
		if rage_timer <= 0.0:
			is_in_rage_mode = false
			current_rage = 0.0

	if buffer_timer > 0.0:
		buffer_timer -= delta
		if buffer_timer <= 0.0:
			input_buffer.clear()

func _process_state(delta: float) -> void:
	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 1000.0 * delta)
			if is_player:
				_handle_player_movement_inputs()
		
		State.WALK_FWD, State.WALK_BWD:
			if is_player:
				_handle_player_movement_inputs()
		
		State.JUMP:
			if is_player:
				_handle_aerial_inputs()
			if velocity.y >= 0:
				_change_state(State.FALL)
		
		State.FALL:
			if is_player:
				_handle_aerial_inputs()
			if is_on_floor():
				_change_state(State.IDLE)
		
		State.CROUCH:
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			if is_player and not Input.is_action_pressed("move_down"):
				_change_state(State.IDLE)
		
		State.ATTACK:
			_advance_attack_frames(delta)
		
		State.BLOCK:
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			if state_time > 0.35:
				_change_state(State.IDLE)
		
		State.PARRY:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if state_time > 0.25:
				_change_state(State.IDLE)
		
		State.HURT:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if state_time > 0.25:
				_change_state(State.IDLE)
		
		State.LAUNCHED:
			if is_on_floor() and state_time > 0.1:
				_change_state(State.KNOCKDOWN)
		
		State.KNOCKDOWN:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			if state_time > 0.6:
				_change_state(State.GETUP)
		
		State.GETUP:
			if state_time > 0.3:
				_change_state(State.IDLE)
		
		State.RAGE_BURST:
			if state_time > 0.4:
				_change_state(State.IDLE)

func _handle_player_movement_inputs() -> void:
	if current_state != State.IDLE and current_state != State.WALK_FWD and current_state != State.WALK_BWD:
		return

	var move_x: float = 0.0
	if Input.is_action_pressed("move_right"):
		move_x += 1.0
	if Input.is_action_pressed("move_left"):
		move_x -= 1.0

	if Input.is_action_just_pressed("move_up") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		_change_state(State.JUMP)
		AudioManager.play_sfx("whoosh")
		return

	if Input.is_action_pressed("move_down") and is_on_floor():
		_change_state(State.CROUCH)
		return

	if Input.is_action_just_pressed("attack_light"):
		_try_perform_attack("light")
		return
	elif Input.is_action_just_pressed("attack_heavy"):
		_try_perform_attack("heavy")
		return
	elif Input.is_action_just_pressed("grab"):
		_try_perform_attack("grab")
		return
	elif Input.is_action_just_pressed("range_attack"):
		_try_throw_ranged()
		return
	elif Input.is_action_just_pressed("rage_trigger"):
		_try_activate_rage()
		return

	if move_x != 0:
		velocity.x = move_x * move_speed
		var is_fwd = (move_x > 0 and facing_direction > 0) or (move_x < 0 and facing_direction < 0)
		_change_state(State.WALK_FWD if is_fwd else State.WALK_BWD)
	else:
		_change_state(State.IDLE)

func _handle_aerial_inputs() -> void:
	var move_x: float = 0.0
	if Input.is_action_pressed("move_right"):
		move_x += 1.0
	if Input.is_action_pressed("move_left"):
		move_x -= 1.0
	velocity.x = move_x * move_speed * 0.85

	if Input.is_action_just_pressed("attack_light") or Input.is_action_just_pressed("attack_heavy"):
		_try_perform_attack("aerial")

func _change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	var old = current_state
	current_state = new_state
	state_time = 0.0
	state_changed.emit(State.keys()[old], State.keys()[new_state])

func _try_perform_attack(type: String) -> void:
	if current_state == State.HURT or current_state == State.KNOCKDOWN or current_state == State.DEAD:
		return
	
	var wpn = GameData.weapons.get(weapon_id, GameData.weapons["fists"])
	var moves: Array = wpn["moves"]
	var selected_move = moves[0]

	if type == "heavy" and moves.size() > 3:
		selected_move = moves[3]
	elif type == "grab" and moves.size() > 5:
		selected_move = moves[moves.size() - 1]
	elif type == "aerial" and moves.size() > 2:
		selected_move = moves[2]

	_start_attack_move(selected_move)

func _start_attack_move(move_dict: Dictionary) -> void:
	current_move = move_dict
	move_phase = "startup"
	move_frame = 0
	_change_state(State.ATTACK)
	hitbox_node.reset_targets()
	hitbox_node.monitoring = false
	AudioManager.play_sfx("whoosh")

func _advance_attack_frames(delta: float) -> void:
	var startup_f = current_move.get("startup", 4)
	var active_f = current_move.get("active", 4)
	var recovery_f = current_move.get("recovery", 8)
	var total_frames = startup_f + active_f + recovery_f
	
	var current_frame_num = int(state_time * 60.0)
	weapon_swing_progress = clampf(float(current_frame_num) / float(total_frames), 0.0, 1.0)
	
	if current_frame_num < startup_f:
		move_phase = "startup"
		hitbox_node.monitoring = false
	elif current_frame_num < (startup_f + active_f):
		move_phase = "active"
		hitbox_node.monitoring = true
		
		# Configure hitbox data
		var raw_dmg = current_move.get("dmg", 15)
		var dmg_scaled = base_atk + raw_dmg
		if is_in_rage_mode:
			dmg_scaled *= (1.3 + (aura_tier * 0.15))
		
		# Check critical hit
		var is_crit = randf() < crit_chance
		if is_crit:
			dmg_scaled *= crit_mult
			flash_timer = 0.08
		
		hitbox_node.damage = dmg_scaled
		var reach = current_move.get("reach", 50)
		hitbox_node.position = Vector2(facing_direction * (reach * 0.7), -60)
		
		var on_hit_str = str(current_move.get("on_hit", ""))
		hitbox_node.is_launcher = (on_hit_str == "launch" or on_hit_str == "juggle")
		hitbox_node.is_trip = (on_hit_str == "trip")
		hitbox_node.knockback_vector = Vector2(facing_direction * (300.0 if hitbox_node.is_launcher else 180.0), -400.0 if hitbox_node.is_launcher else -80.0)
	else:
		move_phase = "recovery"
		hitbox_node.monitoring = false
	
	if current_frame_num >= total_frames:
		hitbox_node.monitoring = false
		_change_state(State.IDLE)

func _try_throw_ranged() -> void:
	if current_state != State.IDLE and current_state != State.WALK_FWD and current_state != State.WALK_BWD:
		return
	
	var proj = Projectile.new()
	proj.attacker = self
	proj.global_position = global_position + Vector2(facing_direction * 35.0, -60.0)
	proj.direction = Vector2(facing_direction, 0.0)
	proj.damage = base_atk * 1.5
	get_parent().add_child(proj)
	AudioManager.play_sfx("slash")

func _try_activate_rage() -> void:
	if current_rage >= 30.0 and not is_in_rage_mode:
		is_in_rage_mode = true
		rage_timer = 10.0
		_change_state(State.RAGE_BURST)
		AudioManager.play_sfx("rage_surge")
		flash_timer = 0.2

func take_hit(hitbox: Hitbox) -> void:
	var raw_damage = hitbox.damage
	var kb = hitbox.knockback_vector
	var is_launcher = hitbox.is_launcher
	var is_trip = hitbox.is_trip
	
	# Parry Check
	if parry_window_timer > 0.0:
		AudioManager.play_sfx("parry")
		flash_timer = 0.15
		if hitbox.attacker != null and hitbox.attacker.has_method("stagger_from_parry"):
			hitbox.attacker.stagger_from_parry()
		return
	
	# Block Check
	var is_blocking = (current_state == State.BLOCK) or (current_state == State.WALK_BWD)
	if is_blocking and not hitbox.is_guard_break:
		AudioManager.play_sfx("block")
		var blocked_dmg = max(1.0, (raw_damage - def_flat) * 0.2)
		current_hp = max(0.0, current_hp - blocked_dmg)
		velocity = Vector2(kb.x * 0.3, 0)
		hitstop_timer = 0.05
		health_changed.emit(current_hp, max_hp)
		_gain_rage(blocked_dmg * 0.5)
		return
	
	# Full Hit resolution
	var final_damage = max(1.0, (raw_damage - def_flat) * (1.0 - def_mitigation))
	current_hp = max(0.0, current_hp - final_damage)
	flash_timer = 0.12
	hitstop_timer = float(hitbox.hitstop_frames) / 60.0
	
	AudioManager.play_sfx("hit_heavy" if final_damage > 25.0 else "hit_light")
	_gain_rage(final_damage * 0.8)
	health_changed.emit(current_hp, max_hp)
	
	# Notify attacker combo tracker
	if hitbox.attacker != null and hitbox.attacker.has_method("on_hit_connected"):
		hitbox.attacker.on_hit_connected(final_damage)
	
	if current_hp <= 0:
		_die()
		return
	
	if is_launcher:
		velocity = kb
		_change_state(State.LAUNCHED)
	elif is_trip:
		velocity = Vector2(kb.x * 0.5, -100.0)
		_change_state(State.KNOCKDOWN)
	else:
		velocity = Vector2(kb.x, 0)
		_change_state(State.HURT)

func take_hit_direct(damage: float, kb: Vector2, is_launcher: bool = false, sound: String = "hit_light") -> void:
	var final_dmg = max(1.0, damage - def_flat)
	current_hp = max(0.0, current_hp - final_dmg)
	health_changed.emit(current_hp, max_hp)
	flash_timer = 0.1
	AudioManager.play_sfx(sound)
	
	if current_hp <= 0:
		_die()
	else:
		velocity = kb
		_change_state(State.LAUNCHED if is_launcher else State.HURT)

func on_hit_connected(dmg: float) -> void:
	combo_count += 1
	combo_damage_accum += dmg
	combo_reset_timer = 2.0
	_gain_rage(dmg * 0.6)
	combo_updated.emit(combo_count, combo_damage_accum)

func stagger_from_parry() -> void:
	hitstop_timer = 0.35
	_change_state(State.HURT)

func _gain_rage(amount: float) -> void:
	if not is_in_rage_mode:
		current_rage = clampf(current_rage + amount, 0.0, max_rage)
		var t = 1 if current_rage >= 33.0 else 0
		if current_rage >= 66.0: t = 2
		if current_rage >= 100.0: t = 3
		rage_changed.emit(current_rage, max_rage, t)

func _die() -> void:
	current_hp = 0.0
	_change_state(State.DEAD)
	AudioManager.play_sfx("ko")
	fighter_died.emit()

# Dynamic Vector Silhouette Renderer
func _draw() -> void:
	var body_color = Color(0.05, 0.05, 0.07, 1.0)
	if flash_timer > 0.0:
		body_color = Color(1.0, 1.0, 1.0, 1.0)
	
	var rim_color = Color(0.2, 0.8, 1.0, 0.8) if is_player else Color(1.0, 0.3, 0.2, 0.8)
	var eye_color = Color(0.0, 0.9, 1.0, 1.0) if is_player else Color(1.0, 0.1, 0.1, 1.0)
	
	if is_in_rage_mode:
		var rage_halo_col = Color(1.0, 0.8, 0.1, 0.5) if aura_tier == 3 else Color(0.9, 0.2, 0.9, 0.5)
		draw_circle(Vector2(0, -60), 45.0 + sin(anim_timer * 15.0) * 5.0, rage_halo_col)
	
	# Draw shadow on ground
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 28.0, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	# Body Articulation Positions
	var head_pos = Vector2(0, -95)
	var chest_pos = Vector2(0, -70)
	var hips_pos = Vector2(0, -45)
	
	# Animate limbs based on state
	var walk_cycle = sin(anim_timer * 12.0)
	var left_foot = hips_pos + Vector2(-15 + walk_cycle * 12 * facing_direction, 45)
	var right_foot = hips_pos + Vector2(15 - walk_cycle * 12 * facing_direction, 45)
	
	if current_state == State.IDLE:
		head_pos.y += sin(anim_timer * 3.0) * 2.0
		chest_pos.y += sin(anim_timer * 3.0) * 1.5
		left_foot = hips_pos + Vector2(-12, 45)
		right_foot = hips_pos + Vector2(12, 45)
	elif current_state == State.CROUCH:
		head_pos.y += 25.0
		chest_pos.y += 20.0
		hips_pos.y += 15.0
	elif current_state == State.KNOCKDOWN or current_state == State.DEAD:
		head_pos = Vector2(facing_direction * -40, -10)
		chest_pos = Vector2(facing_direction * -20, -10)
		hips_pos = Vector2(0, -10)
		left_foot = Vector2(facing_direction * 30, -5)
		right_foot = Vector2(facing_direction * 40, -5)

	# Draw Legs
	draw_line(hips_pos, hips_pos + (left_foot - hips_pos) * 0.5, body_color, 8.0)
	draw_line(hips_pos + (left_foot - hips_pos) * 0.5, left_foot, body_color, 7.0)
	draw_line(hips_pos, hips_pos + (right_foot - hips_pos) * 0.5, body_color, 8.0)
	draw_line(hips_pos + (right_foot - hips_pos) * 0.5, right_foot, body_color, 7.0)

	# Draw Torso
	draw_line(hips_pos, chest_pos, body_color, 14.0)
	draw_line(chest_pos, head_pos + Vector2(0, 8), body_color, 12.0)

	# Draw Head & Glowing Eye
	draw_circle(head_pos, 11.0, body_color)
	draw_circle(head_pos + Vector2(facing_direction * 5, -2), 2.5, eye_color)

	# Draw Arms & Weapon
	var hand_pos = chest_pos + Vector2(facing_direction * 22, 5)
	if current_state == State.ATTACK:
		var swing_angle = lerp(-PI * 0.4, PI * 0.6, weapon_swing_progress) * facing_direction
		hand_pos = chest_pos + Vector2(cos(swing_angle) * 35.0, sin(swing_angle) * 30.0)
	
	draw_line(chest_pos, hand_pos, body_color, 7.0)
	_draw_weapon(hand_pos, body_color, rim_color)

func _draw_weapon(hand_pos: Vector2, col: Color, rim: Color) -> void:
	match weapon_id:
		"daggers", "sais":
			draw_line(hand_pos, hand_pos + Vector2(facing_direction * 20, -5), col, 3.5)
			draw_line(hand_pos, hand_pos + Vector2(facing_direction * 20, -5), rim, 1.5)
		"katana", "composite_sword", "blood_reaper":
			var blade_tip = hand_pos + Vector2(facing_direction * 45, -20)
			draw_line(hand_pos, blade_tip, col, 4.0)
			draw_line(hand_pos, blade_tip, rim, 1.5)
		"staff":
			var tip_a = hand_pos + Vector2(facing_direction * -35, 15)
			var tip_b = hand_pos + Vector2(facing_direction * 45, -25)
			draw_line(tip_a, tip_b, Color(0.35, 0.22, 0.12), 4.5)
		"scythe":
			var pole_end = hand_pos + Vector2(facing_direction * 40, -35)
			draw_line(hand_pos + Vector2(facing_direction * -20, 20), pole_end, col, 4.0)
			draw_line(pole_end, pole_end + Vector2(facing_direction * -25, -20), rim, 3.5)
		"hammer":
			var hammer_head = hand_pos + Vector2(facing_direction * 35, -25)
			draw_line(hand_pos, hammer_head, Color(0.3, 0.3, 0.3), 4.5)
			draw_rect(Rect2(hammer_head - Vector2(10, 10), Vector2(20, 20)), col)
		"nunchaku", "batons":
			draw_line(hand_pos, hand_pos + Vector2(facing_direction * 25, 10), col, 4.0)
		"ak47":
			draw_rect(Rect2(hand_pos + Vector2(0, -6), Vector2(facing_direction * 32, 12)), col)
		_: # Fists
			draw_circle(hand_pos, 5.0, col)
