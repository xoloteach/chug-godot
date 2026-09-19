extends CanvasLayer
## InputController: bridges player input to the hero + camera, and owns the
## mobile on-screen controls (virtual joystick + action buttons).
##
## Detection: touch UI is shown when the device is a touchscreen, reports the
## "mobile" feature, or the viewport is small/portrait (so desktop testers on a
## narrow window still get it). Because emulate_touch_from_mouse is enabled, the
## joystick works with the mouse too.
##
## Keyboard/mouse (desktop): WASD/arrows move the hero, left-drag orbits camera.

signal toggle_upgrades()
signal toggle_story()
signal boost_pressed()

@export var main_path: NodePath
@export var orbit_speed: float = 0.006
@export var force_touch_controls: bool = false

var _main: Node3D
var _hero: Node3D
var _joystick: Control
var _dragging_camera: bool = false
var _touch_mode: bool = false


func _ready() -> void:
	_joystick = get_node_or_null("Controls/Joystick")
	if _joystick != null and _joystick.has_signal("direction_changed"):
		_joystick.direction_changed.connect(_on_joystick_dir)
	_wire_button("Controls/Buttons/BoostButton", _on_boost)
	_wire_button("Controls/Buttons/UpgradesButton", func(): toggle_upgrades.emit())
	_wire_button("Controls/Buttons/StoryButton", func(): toggle_story.emit())

	_resolve_main()
	_update_touch_mode()
	get_viewport().size_changed.connect(_update_touch_mode)


func _wire_button(path: String, cb: Callable) -> void:
	var b := get_node_or_null(path)
	if b != null and b is BaseButton:
		b.pressed.connect(cb)


func _resolve_main() -> void:
	if main_path != NodePath("") and has_node(main_path):
		_main = get_node(main_path)
	else:
		# Fallback: the Main node is our owner or a sibling.
		_main = get_tree().current_scene as Node3D
	if _main != null:
		_hero = _main.get_node_or_null("Hero")


func _update_touch_mode() -> void:
	var vp := get_viewport().get_visible_rect().size
	var small := vp.x < 820.0 or vp.x < vp.y # narrow or portrait
	var touch := DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	_touch_mode = force_touch_controls or touch or small
	var controls := get_node_or_null("Controls")
	if controls != null and controls is CanvasItem:
		(controls as CanvasItem).visible = _touch_mode


func _process(_delta: float) -> void:
	if _hero == null and _main != null:
		_hero = _main.get_node_or_null("Hero")
	if _hero == null:
		return
	var dir := _read_move_direction()
	if _hero.has_method("set_player_direction"):
		_hero.set_player_direction(dir)


## Combine keyboard (desktop) and joystick (touch) into one XZ direction.
## Screen up (-y on joystick) maps to -Z in world (away from camera).
func _read_move_direction() -> Vector2:
	var dir := Vector2.ZERO
	# Keyboard: use raw key checks so we need no input map entries.
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if _joystick != null:
		var j: Vector2 = _joystick.output
		if j.length() > 0.0:
			dir += j
	if dir.length() > 1.0:
		dir = dir.normalized()
	return dir


func _on_joystick_dir(_dir: Vector2) -> void:
	# Direction is polled in _process via _joystick.output; nothing to do here.
	pass


func _on_boost() -> void:
	boost_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	# Desktop camera orbit via left-drag. On touch we reserve drags for the
	# joystick/UI, so only orbit with the mouse button here.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging_camera = event.pressed and not _touch_mode
	elif event is InputEventMouseMotion and _dragging_camera and _main != null:
		if _main.has_method("add_camera_orbit"):
			_main.add_camera_orbit(-event.relative.x * orbit_speed)
