extends Control
## VirtualJoystick: a draggable on-screen stick for touch (and mouse, thanks to
## emulate_touch_from_mouse). Exposes a normalized Vector2 in `output` where
## (0,-1) is up on screen. Emits `direction_changed` while active.
##
## Structure (built in code so it needs no scene wiring):
##   - a circular "base" ring
##   - a "knob" that follows the finger, clamped to the base radius
##
## The joystick captures a touch that begins anywhere inside its Control rect.

signal direction_changed(dir: Vector2)

@export var base_radius: float = 70.0
@export var knob_radius: float = 32.0
## Deadzone as a fraction of base_radius.
@export var deadzone: float = 0.15

var output: Vector2 = Vector2.ZERO

var _touch_index: int = -1
var _active: bool = false
var _center: Vector2 = Vector2.ZERO
var _knob_offset: Vector2 = Vector2.ZERO

var _base_color := Color(1, 1, 1, 0.18)
var _base_ring := Color(1, 1, 1, 0.35)
var _knob_color := Color(0.55, 0.75, 1.0, 0.65)


func _ready() -> void:
	# Fill assigned area; the base is centered within it.
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(base_radius * 2.4, base_radius * 2.4)
	_recenter()
	resized.connect(_recenter)


func _recenter() -> void:
	_center = size * 0.5
	_knob_offset = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	# Base disc + ring.
	draw_circle(_center, base_radius, _base_color)
	draw_arc(_center, base_radius, 0.0, TAU, 48, _base_ring, 3.0, true)
	# Knob.
	var knob_pos := _center + _knob_offset
	draw_circle(knob_pos, knob_radius, _knob_color)
	draw_arc(knob_pos, knob_radius, 0.0, TAU, 32, Color(1, 1, 1, 0.6), 2.0, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not _active:
			_active = true
			_touch_index = event.index
			_update_knob(event.position)
			accept_event()
		elif not event.pressed and event.index == _touch_index:
			_release()
			accept_event()
	elif event is InputEventScreenDrag and _active and event.index == _touch_index:
		_update_knob(event.position)
		accept_event()


func _update_knob(local_pos: Vector2) -> void:
	var v := local_pos - _center
	if v.length() > base_radius:
		v = v.normalized() * base_radius
	_knob_offset = v
	var norm := v / base_radius
	if norm.length() < deadzone:
		output = Vector2.ZERO
	else:
		output = norm
	direction_changed.emit(output)
	queue_redraw()


func _release() -> void:
	_active = false
	_touch_index = -1
	_knob_offset = Vector2.ZERO
	output = Vector2.ZERO
	direction_changed.emit(output)
	queue_redraw()
