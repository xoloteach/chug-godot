extends Node3D
## Main: assembles the playable 3D world.
##
## Responsibilities:
##   * Instance the Blender GLB models: a tiled ground, scattered props
##     (trees, rocks, crystals, chests, enemies, runes) and the Hero.
##   * Drive a third-person follow camera that trails and slightly orbits.
##   * Own a WorldEnvironment (sky/ambient/fog) + DirectionalLight and re-theme
##     them per current zone.
##   * Advance the economy every frame via GameState.tick(delta).

const HERO_SCENE := preload("res://main/Hero.tscn")

const MODEL_TREE := preload("res://assets/models/tree.glb")
const MODEL_ROCK := preload("res://assets/models/rock.glb")
const MODEL_CRYSTAL := preload("res://assets/models/crystal.glb")
const MODEL_CHEST := preload("res://assets/models/chest.glb")
const MODEL_ENEMY := preload("res://assets/models/enemy.glb")
const MODEL_RUNE := preload("res://assets/models/rune.glb")
const MODEL_COIN := preload("res://assets/models/coin.glb")
const MODEL_GROUND := preload("res://assets/models/ground.glb")

## Half-size of the playable area (matches Hero.roam_radius roughly).
const WORLD_HALF := 20.0

# Per-zone visual theme: ground tint, fog color, ambient tint, sun tint.
const ZONE_THEMES := {
	"greenwood": {
		"ground": Color(0.36, 0.52, 0.30),
		"fog": Color(0.62, 0.74, 0.68),
		"ambient": Color(0.45, 0.50, 0.48),
		"sun": Color(1.0, 0.97, 0.88),
		"sky_top": Color(0.35, 0.55, 0.85),
		"sky_horizon": Color(0.70, 0.82, 0.92),
	},
	"emberpeak": {
		"ground": Color(0.42, 0.30, 0.22),
		"fog": Color(0.72, 0.50, 0.36),
		"ambient": Color(0.55, 0.40, 0.32),
		"sun": Color(1.0, 0.82, 0.62),
		"sky_top": Color(0.55, 0.40, 0.42),
		"sky_horizon": Color(0.85, 0.60, 0.42),
	},
	"sunkencrypt": {
		"ground": Color(0.24, 0.30, 0.32),
		"fog": Color(0.30, 0.42, 0.44),
		"ambient": Color(0.28, 0.40, 0.42),
		"sun": Color(0.70, 0.85, 0.88),
		"sky_top": Color(0.12, 0.22, 0.28),
		"sky_horizon": Color(0.28, 0.44, 0.48),
	},
	"frostspire": {
		"ground": Color(0.70, 0.76, 0.82),
		"fog": Color(0.78, 0.86, 0.94),
		"ambient": Color(0.60, 0.68, 0.78),
		"sun": Color(0.90, 0.95, 1.0),
		"sky_top": Color(0.55, 0.68, 0.85),
		"sky_horizon": Color(0.82, 0.90, 0.97),
	},
	"voidgate": {
		"ground": Color(0.20, 0.16, 0.28),
		"fog": Color(0.28, 0.20, 0.40),
		"ambient": Color(0.34, 0.26, 0.46),
		"sun": Color(0.72, 0.60, 0.95),
		"sky_top": Color(0.10, 0.06, 0.18),
		"sky_horizon": Color(0.32, 0.18, 0.42),
	},
}

@onready var _env: WorldEnvironment = $WorldEnvironment
@onready var _sun: DirectionalLight3D = $DirectionalLight3D
@onready var _camera: Camera3D = $Camera3D
@onready var _ground_root: Node3D = $Ground
@onready var _props_root: Node3D = $Props

var _hero: Node3D
var _ground_material: StandardMaterial3D
var _coins: Array[Node3D] = []

# Camera follow parameters.
@export var cam_distance: float = 10.0
@export var cam_height: float = 6.5
@export var cam_smooth: float = 4.0
var camera_orbit: float = 0.0 # radians, driven by InputController drag.


func _ready() -> void:
	randomize()
	_build_ground()
	_scatter_props()
	_spawn_hero()
	_ensure_environment()
	_wire_controls()
	if has_node("/root/GameState"):
		var gs := get_node("/root/GameState")
		if not gs.zone_unlocked.is_connected(_on_zone_unlocked):
			gs.zone_unlocked.connect(_on_zone_unlocked)
		_apply_theme(gs.current_zone)
	else:
		_apply_theme("greenwood")


func _process(delta: float) -> void:
	# Drive the idle economy every frame.
	if has_node("/root/GameState"):
		get_node("/root/GameState").tick(delta)
	_spin_coins(delta)
	_update_camera(delta)


# --- World construction ------------------------------------------------

func _build_ground() -> void:
	# The ground.glb tile is ~4 units; tile it into a large plane grid.
	var tile_size := 4.0
	var tiles := int(ceil((WORLD_HALF * 2.0) / tile_size)) + 2
	var start := -tiles * 0.5 * tile_size + tile_size * 0.5
	# One shared material we can recolor per zone.
	_ground_material = StandardMaterial3D.new()
	_ground_material.albedo_color = Color(0.36, 0.52, 0.30)
	_ground_material.roughness = 1.0
	for ix in range(tiles):
		for iz in range(tiles):
			var tile := MODEL_GROUND.instantiate()
			tile.position = Vector3(start + ix * tile_size, 0.0, start + iz * tile_size)
			_apply_material_recursive(tile, _ground_material)
			_ground_root.add_child(tile)


func _scatter_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240921
	var specs := [
		{"scene": MODEL_TREE, "count": 26, "scale": Vector2(0.9, 1.4)},
		{"scene": MODEL_ROCK, "count": 16, "scale": Vector2(0.7, 1.6)},
		{"scene": MODEL_CRYSTAL, "count": 8, "scale": Vector2(0.8, 1.3)},
		{"scene": MODEL_CHEST, "count": 5, "scale": Vector2(0.9, 1.1)},
		{"scene": MODEL_ENEMY, "count": 7, "scale": Vector2(0.8, 1.2)},
		{"scene": MODEL_RUNE, "count": 4, "scale": Vector2(0.9, 1.2)},
		{"scene": MODEL_COIN, "count": 10, "scale": Vector2(0.9, 1.3)},
	]
	for spec in specs:
		var is_coin: bool = spec["scene"] == MODEL_COIN
		for i in range(spec["count"]):
			var inst: Node3D = spec["scene"].instantiate()
			var pos := _random_ground_pos(rng)
			# Keep a clearing near the spawn point.
			while pos.length() < 3.0:
				pos = _random_ground_pos(rng)
			var s: float = rng.randf_range(spec["scale"].x, spec["scale"].y)
			inst.scale = Vector3(s, s, s)
			inst.rotation.y = rng.randf_range(0.0, TAU)
			if is_coin:
				# Float coins slightly above the ground so they read as pickups
				# and track them for a gentle idle spin.
				pos.y = 0.6
				inst.position = pos
				_coins.append(inst)
			else:
				inst.position = pos
			_props_root.add_child(inst)


func _random_ground_pos(rng: RandomNumberGenerator) -> Vector3:
	return Vector3(
		rng.randf_range(-WORLD_HALF, WORLD_HALF),
		0.0,
		rng.randf_range(-WORLD_HALF, WORLD_HALF)
	)


func _spawn_hero() -> void:
	_hero = HERO_SCENE.instantiate()
	_hero.position = Vector3.ZERO
	add_child(_hero)


# --- Environment / theming --------------------------------------------

func _ensure_environment() -> void:
	if _env.environment == null:
		_env.environment = Environment.new()
	var e := _env.environment
	# Procedural sky for a pleasant gradient background.
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	sky.sky_material = mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.6
	# Depth fog.
	e.fog_enabled = true
	e.fog_density = 0.015
	# Soft tonemap for nicer color.
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC


func _apply_theme(zone_id: String) -> void:
	var theme: Dictionary = ZONE_THEMES.get(zone_id, ZONE_THEMES["greenwood"])
	if _ground_material != null:
		_ground_material.albedo_color = theme["ground"]
	if _env.environment != null:
		var e := _env.environment
		e.fog_light_color = theme["fog"]
		e.ambient_light_color = theme["ambient"]
		var mat := e.sky.sky_material if e.sky != null else null
		if mat is ProceduralSkyMaterial:
			mat.sky_top_color = theme["sky_top"]
			mat.sky_horizon_color = theme["sky_horizon"]
			mat.ground_horizon_color = theme["sky_horizon"]
			mat.ground_bottom_color = theme["ground"]
	if _sun != null:
		_sun.light_color = theme["sun"]


func _on_zone_unlocked(zone_id: String) -> void:
	_apply_theme(zone_id)


# --- Control wiring ----------------------------------------------------

func _wire_controls() -> void:
	var input_ctrl := get_node_or_null("InputController")
	var ui := get_node_or_null("UI")
	if input_ctrl == null:
		return
	# Point the controller at this Main node so it can find the Hero + camera.
	input_ctrl.main_path = input_ctrl.get_path_to(self)
	if ui != null:
		if input_ctrl.has_signal("toggle_upgrades") and ui.has_method("toggle_upgrades_panel"):
			input_ctrl.toggle_upgrades.connect(ui.toggle_upgrades_panel)
		if input_ctrl.has_signal("toggle_story") and ui.has_method("toggle_story_panel"):
			input_ctrl.toggle_story.connect(ui.toggle_story_panel)


# --- Camera ------------------------------------------------------------

func _update_camera(delta: float) -> void:
	if _hero == null:
		return
	var target := _hero.global_position
	var offset := Vector3(
		sin(camera_orbit) * cam_distance,
		cam_height,
		cos(camera_orbit) * cam_distance
	)
	var desired := target + offset
	var t := clampf(cam_smooth * delta, 0.0, 1.0)
	_camera.global_position = _camera.global_position.lerp(desired, t)
	_camera.look_at(target + Vector3(0, 1.0, 0), Vector3.UP)


func add_camera_orbit(amount: float) -> void:
	camera_orbit += amount


# --- Coins -------------------------------------------------------------

func _spin_coins(delta: float) -> void:
	# Idle spin so the scattered reward coins catch the eye.
	for coin in _coins:
		if is_instance_valid(coin):
			coin.rotation.y += delta * 1.5


# --- Helpers -----------------------------------------------------------

func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in range(mi.get_surface_override_material_count()):
			mi.set_surface_override_material(i, mat)
		if mi.get_surface_override_material_count() == 0 and mi.mesh != null:
			mi.material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)
