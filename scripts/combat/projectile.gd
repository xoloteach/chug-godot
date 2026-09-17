extends Area2D
class_name Projectile

## Projectile - Ranged weapon entity (Shuriken, Kunai, Boomerang Sickle, AK Bullet, Magic Orb)

@export var speed: float = 800.0
@export var damage: float = 20.0
@export var direction: Vector2 = Vector2.RIGHT
@export var max_lifetime: float = 3.0
@export var projectile_type: String = "shuriken"
@export var attacker: Node = null

var lifetime: float = 0.0
var visual_rotation: float = 0.0

func _ready() -> void:
	monitoring = true
	monitorable = true
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime += delta
	visual_rotation += 25.0 * delta
	queue_redraw()
	
	if lifetime >= max_lifetime:
		queue_free()

func _draw() -> void:
	match projectile_type:
		"shuriken":
			draw_set_transform(Vector2.ZERO, visual_rotation)
			var col = Color(0.2, 0.9, 1.0, 1.0)
			draw_line(Vector2(-10, 0), Vector2(10, 0), col, 2.5)
			draw_line(Vector2(0, -10), Vector2(0, 10), col, 2.5)
			draw_circle(Vector2.ZERO, 3.0, Color.WHITE)
		"kunai":
			draw_set_transform(Vector2.ZERO, direction.angle())
			draw_polygon(PackedVector2Array([Vector2(12, 0), Vector2(-8, -4), Vector2(-8, 4)]), PackedColorArray([Color(0.8, 0.2, 0.9)]))
		"magic_orb":
			draw_circle(Vector2.ZERO, 10.0, Color(1.0, 0.4, 0.1, 0.8))
			draw_circle(Vector2.ZERO, 5.0, Color.WHITE)
		"bullet":
			draw_set_transform(Vector2.ZERO, direction.angle())
			draw_line(Vector2(-15, 0), Vector2(15, 0), Color(1.0, 0.9, 0.3), 3.0)
		_:
			draw_circle(Vector2.ZERO, 6.0, Color.CYAN)

func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("hurtbox"):
		return
	
	var victim = area.get_parent()
	if victim == attacker:
		return
	
	if victim.has_method("take_hit_direct"):
		victim.take_hit_direct(damage, direction * 150.0, false, "ranged")
		AudioManager.play_sfx("hit_light")
		queue_free()
