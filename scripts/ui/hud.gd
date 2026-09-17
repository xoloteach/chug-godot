extends Control
class_name CombatHUD

## CombatHUD - High polish fighting game UI
## Displays HP bars, 3-tier Rage meters, Combo counters, 99s Round Timer, and Touch controls.

var player_fighter: Fighter
var enemy_fighter: Fighter

var player_hp_ratio: float = 1.0
var player_target_hp: float = 1.0
var enemy_hp_ratio: float = 1.0
var enemy_target_hp: float = 1.0

var player_rage_ratio: float = 0.0
var enemy_rage_ratio: float = 0.0

var round_time_remaining: float = 99.0
var combo_count: int = 0
var combo_damage: float = 0.0
var announcement_text: String = ""
var announcement_timer: float = 0.0

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)

func init_hud(p_fighter: Fighter, e_fighter: Fighter) -> void:
	player_fighter = p_fighter
	enemy_fighter = e_fighter
	
	player_fighter.health_changed.connect(_on_player_health_changed)
	player_fighter.rage_changed.connect(_on_player_rage_changed)
	player_fighter.combo_updated.connect(_on_combo_updated)
	
	enemy_fighter.health_changed.connect(_on_enemy_health_changed)
	enemy_fighter.rage_changed.connect(_on_enemy_rage_changed)

func _process(delta: float) -> void:
	player_hp_ratio = lerp(player_hp_ratio, player_target_hp, 12.0 * delta)
	enemy_hp_ratio = lerp(enemy_hp_ratio, enemy_target_hp, 12.0 * delta)
	
	if announcement_timer > 0.0:
		announcement_timer -= delta
	
	queue_redraw()

func _on_player_health_changed(cur: float, mx: float) -> void:
	player_target_hp = clampf(cur / mx, 0.0, 1.0)

func _on_player_rage_changed(cur: float, mx: float, _tier: int) -> void:
	player_rage_ratio = clampf(cur / mx, 0.0, 1.0)

func _on_enemy_health_changed(cur: float, mx: float) -> void:
	enemy_target_hp = clampf(cur / mx, 0.0, 1.0)

func _on_enemy_rage_changed(cur: float, mx: float, _tier: int) -> void:
	enemy_rage_ratio = clampf(cur / mx, 0.0, 1.0)

func _on_combo_updated(hits: int, dmg: float) -> void:
	combo_count = hits
	combo_damage = dmg

func show_announcement(text: String, duration: float = 1.5) -> void:
	announcement_text = text
	announcement_timer = duration

func _draw() -> void:
	var screen_w = size.x
	
	# Top Health Bar Backgrounds
	var bar_w = 420.0
	var bar_h = 24.0
	var top_margin = 35.0
	
	# Player Health Bar (Left)
	var p_pos = Vector2(40, top_margin)
	draw_rect(Rect2(p_pos - Vector2(2, 2), Vector2(bar_w + 4, bar_h + 4)), Color(0.1, 0.1, 0.12, 0.9))
	draw_rect(Rect2(p_pos, Vector2(bar_w, bar_h)), Color(0.3, 0.1, 0.1, 0.8)) # Red background
	draw_rect(Rect2(p_pos, Vector2(bar_w * player_hp_ratio, bar_h)), Color(0.15, 0.85, 1.0, 1.0)) # Cyan active HP
	
	# Player Rage Bar (Below HP)
	var p_rage_pos = Vector2(40, top_margin + bar_h + 6)
	draw_rect(Rect2(p_rage_pos, Vector2(bar_w * player_rage_ratio, 8)), Color(1.0, 0.7, 0.1, 1.0))
	
	# Player Name & Level
	var p_name = SaveStore.data["player"]["name"] + " (Lv.%d)" % SaveStore.data["player"]["level"]
	draw_string(ThemeDB.fallback_font, Vector2(40, top_margin - 8), p_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

	# Enemy Health Bar (Right)
	var e_pos = Vector2(screen_w - 40 - bar_w, top_margin)
	draw_rect(Rect2(e_pos - Vector2(2, 2), Vector2(bar_w + 4, bar_h + 4)), Color(0.1, 0.1, 0.12, 0.9))
	draw_rect(Rect2(e_pos, Vector2(bar_w, bar_h)), Color(0.3, 0.1, 0.1, 0.8))
	var e_fill_w = bar_w * enemy_hp_ratio
	draw_rect(Rect2(Vector2(e_pos.x + (bar_w - e_fill_w), e_pos.y), Vector2(e_fill_w, bar_h)), Color(1.0, 0.25, 0.25, 1.0))
	
	# Enemy Rage Bar
	var e_rage_pos = Vector2(e_pos.x + (bar_w - bar_w * enemy_rage_ratio), top_margin + bar_h + 6)
	draw_rect(Rect2(e_rage_pos, Vector2(bar_w * enemy_rage_ratio, 8)), Color(0.9, 0.1, 0.8, 1.0))
	
	# Enemy Name
	var e_name = enemy_fighter.character_id.to_upper() if enemy_fighter else "DRAKO"
	draw_string(ThemeDB.fallback_font, Vector2(screen_w - 40, top_margin - 8), e_name, HORIZONTAL_ALIGNMENT_RIGHT, -1, 18, Color(1.0, 0.8, 0.8))

	# Center Timer
	var timer_rect = Rect2(Vector2(screen_w * 0.5 - 35, top_margin - 10), Vector2(70, 45))
	draw_rect(timer_rect, Color(0.05, 0.05, 0.08, 0.9))
	draw_string(ThemeDB.fallback_font, Vector2(screen_w * 0.5, top_margin + 25), "%02d" % int(round_time_remaining), HORIZONTAL_ALIGNMENT_CENTER, -1, 28, Color.GOLD)

	# Combo Counter
	if combo_count > 1:
		var combo_str = "%d HITS!" % combo_count
		draw_string(ThemeDB.fallback_font, Vector2(70, 160), combo_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1.0, 0.85, 0.2))
		var dmg_str = "DMG: %d" % int(combo_damage)
		draw_string(ThemeDB.fallback_font, Vector2(70, 190), dmg_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.9))

	# Center Screen Announcement (ROUND 1, FIGHT, K.O.)
	if announcement_timer > 0.0:
		var scale_pulse = 1.0 + (announcement_timer * 0.1)
		draw_string(ThemeDB.fallback_font, Vector2(screen_w * 0.5, size.y * 0.45), announcement_text, HORIZONTAL_ALIGNMENT_CENTER, -1, int(48 * scale_pulse), Color.WHITE)
