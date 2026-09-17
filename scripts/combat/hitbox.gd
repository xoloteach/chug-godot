extends Area2D
class_name Hitbox

## Hitbox - Combat collision volume conveying damage, knockback, and hit effects

@export var damage: float = 10.0
@export var knockback_vector: Vector2 = Vector2(250.0, -100.0)
@export var hitstop_frames: int = 6
@export var is_guard_break: bool = false
@export var is_launcher: bool = false
@export var is_trip: bool = false
@export var is_bleed: bool = false
@export var attack_type: String = "light"
@export var attacker: Node = null

var hit_targets: Array[Node] = []

func _ready() -> void:
	monitoring = true
	monitorable = true
	area_entered.connect(_on_area_entered)

func reset_targets() -> void:
	hit_targets.clear()

func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("hurtbox"):
		return
	
	var victim = area.get_parent()
	if victim == attacker or hit_targets.has(victim):
		return
	
	hit_targets.append(victim)
	if victim.has_method("take_hit"):
		victim.take_hit(self)
