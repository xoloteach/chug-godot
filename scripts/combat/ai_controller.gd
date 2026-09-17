extends Node
class_name AIController

## AIController - Decision brain for 25+ enemy variants and Drako Bosses
## Operates reactive spacing, mixup selection, guard blocking, and rage triggers.

@export var fighter: Fighter
@export var ai_tier: int = 1 # 1: Minion, 2: Veteran, 3: Boss/Enforcer, 4: Drako Commander, 5: Xollonox

var decision_timer: float = 0.0
var target_distance: float = 80.0
var aggro_state: String = "approach" # approach, retreat, attack, defend, wait

func _ready() -> void:
	if fighter == null and get_parent() is Fighter:
		fighter = get_parent()

func _physics_process(delta: float) -> void:
	if fighter == null or fighter.current_state == Fighter.State.DEAD or fighter.opponent == null:
		return
	
	decision_timer -= delta
	if decision_timer <= 0.0:
		_evaluate_tactics()
		decision_timer = randf_range(0.15, 0.45) / float(ai_tier)

func _evaluate_tactics() -> void:
	var dist = abs(fighter.global_position.x - fighter.opponent.global_position.x)
	var opp = fighter.opponent
	
	# Check for Rage burst if available
	if fighter.current_rage >= 30.0 and not fighter.is_in_rage_mode and (fighter.current_hp < fighter.max_hp * 0.5 or ai_tier >= 4):
		fighter._try_activate_rage()
		return
	
	# React to incoming attacks (Block or Parry)
	if opp.current_state == Fighter.State.ATTACK and dist < 120.0:
		var block_chance = 0.2 + (ai_tier * 0.15)
		if randf() < block_chance:
			fighter.current_state = Fighter.State.BLOCK
			if ai_tier >= 3 and randf() < 0.35:
				fighter.parry_window_timer = 0.15
			return

	# Attack range checks
	var attack_range = 65.0
	if fighter.weapon_id == "staff" or fighter.weapon_id == "scythe" or fighter.weapon_id == "spear":
		attack_range = 95.0
	elif fighter.weapon_id == "ak47":
		attack_range = 280.0
	
	if dist <= attack_range:
		# Close range offense
		var roll = randf()
		if roll < 0.5:
			fighter._try_perform_attack("light")
		elif roll < 0.85:
			fighter._try_perform_attack("heavy")
		else:
			fighter._try_perform_attack("grab")
	elif dist < 220.0 and randf() < (0.15 * ai_tier):
		# Mid-range poke or ranged tool
		if randf() < 0.4:
			fighter._try_throw_ranged()
		else:
			_move_towards_target()
	else:
		_move_towards_target()

func _move_towards_target() -> void:
	if fighter.opponent == null:
		return
	
	var dir_to_target = sign(fighter.opponent.global_position.x - fighter.global_position.x)
	fighter.velocity.x = dir_to_target * fighter.move_speed
	
	# Occasional jump approach for higher tiers
	if ai_tier >= 2 and randf() < 0.08 and fighter.is_on_floor():
		fighter.velocity.y = fighter.JUMP_VELOCITY
		fighter._change_state(Fighter.State.JUMP)
	else:
		fighter._change_state(Fighter.State.WALK_FWD)
