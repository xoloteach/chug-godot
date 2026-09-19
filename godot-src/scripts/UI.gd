extends CanvasLayer
## UI: the full 2D interface layered over the 3D world.
##
## Builds and drives:
##   * Top HUD: gold, essence, income/sec (K/M/B/T formatted), zone + chapter.
##   * Upgrades panel: scrollable buttons (name, Lv, cost, effect), buy on press,
##     disabled when unaffordable.
##   * Zones/Chapters panel: unlock next zone, reveal chapter story as unlocked.
##   * Welcome-back offline popup, first-load intro overlay, settings/reset.
##
## Updates come from GameState signals plus a light _process refresh of the
## currency labels so the numbers tick smoothly.

var _gs: Node
var _story: Node
var _save: Node

# HUD labels.
@onready var _gold_label: Label = $HUD/Bar/Row/Currencies/GoldRow/GoldValue
@onready var _essence_label: Label = $HUD/Bar/Row/Currencies/EssenceRow/EssenceValue
@onready var _income_label: Label = $HUD/Bar/Row/Currencies/IncomeRow/IncomeValue
@onready var _zone_label: Label = $HUD/Bar/Row/ChapterBox/ZoneName
@onready var _chapter_label: Label = $HUD/Bar/Row/ChapterBox/ChapterText

# Panels.
@onready var _upgrades_panel: Panel = $UpgradesPanel
@onready var _upgrades_list: VBoxContainer = $UpgradesPanel/Margin/Content/Scroll/List
@onready var _zones_panel: Panel = $ZonesPanel
@onready var _zones_list: VBoxContainer = $ZonesPanel/Margin/Content/Scroll/List

# Overlays.
@onready var _intro_overlay: Panel = $IntroOverlay
@onready var _intro_text: Label = $IntroOverlay/Center/Box/IntroText
@onready var _offline_popup: Panel = $OfflinePopup
@onready var _offline_text: Label = $OfflinePopup/Center/Box/OfflineText

# Buttons that toggle panels.
@onready var _btn_upgrades: Button = $HUD/Bar/Row/Tabs/UpgradesTab
@onready var _btn_zones: Button = $HUD/Bar/Row/Tabs/ZonesTab
@onready var _btn_reset: Button = $HUD/Bar/Row/Tabs/ResetButton

var _upgrade_rows: Dictionary = {}   # id -> {button,name,cost,effect}
var _revealed_chapters: int = 1
var _essence_flash: float = 0.0
var _last_essence: float = 0.0


func _ready() -> void:
	_gs = get_node_or_null("/root/GameState")
	_story = get_node_or_null("/root/StoryGenerator")
	_save = get_node_or_null("/root/SaveManager")

	_build_upgrade_rows()
	_build_zone_rows()

	_btn_upgrades.pressed.connect(func(): _toggle_panel(_upgrades_panel))
	_btn_zones.pressed.connect(func(): _toggle_panel(_zones_panel))
	_btn_reset.pressed.connect(_on_reset)
	$IntroOverlay/Center/Box/CloseIntro.pressed.connect(func(): _intro_overlay.visible = false)
	$OfflinePopup/Center/Box/CloseOffline.pressed.connect(func(): _offline_popup.visible = false)

	_upgrades_panel.visible = false
	_zones_panel.visible = false
	_offline_popup.visible = false

	if _gs != null:
		_gs.currency_changed.connect(_on_currency_changed)
		_gs.rates_changed.connect(_on_rates_changed)
		_gs.upgrade_bought.connect(_on_upgrade_bought)
		_gs.zone_unlocked.connect(_on_zone_unlocked)
		_last_essence = _gs.essence
	if _save != null:
		_save.offline_earnings_ready.connect(_on_offline_ready)
		_save.game_loaded.connect(_refresh_all)

	_refresh_all()

	# Autoloads (incl. SaveManager) initialize before this UI scene exists, so
	# the offline_earnings_ready / game_loaded signals fired during
	# SaveManager._ready() have already been emitted and cannot be caught here.
	# Read the state directly instead:
	#   * a brand-new game (no prior save) shows the origin-story intro;
	#   * a returning player with offline gold gets the welcome-back popup.
	if _save != null and not _save.is_new_game:
		if _save.offline_gold > 0.0:
			_on_offline_ready(_save.offline_gold, _save.offline_seconds)
	else:
		_show_intro()


func _process(delta: float) -> void:
	# Smoothly refresh currency labels (they tick continuously).
	if _gs != null:
		_gold_label.text = _fmt(_gs.gold)
		_essence_label.text = _fmt(_gs.essence)
		# Essence gain feedback: subtle pulse when essence increases.
		if _gs.essence > _last_essence + 0.001:
			_essence_flash = 1.0
		_last_essence = _gs.essence
		_refresh_affordability()
	if _essence_flash > 0.0:
		_essence_flash = maxf(0.0, _essence_flash - delta * 2.0)
		var c := Color(0.55, 0.85, 1.0).lerp(Color(1, 1, 1), 1.0 - _essence_flash)
		_essence_label.add_theme_color_override("font_color", c)


# --- Number formatting -------------------------------------------------

func _fmt(value: float) -> String:
	var v := absf(value)
	var sign_s := "-" if value < 0.0 else ""
	if v < 1000.0:
		return "%s%d" % [sign_s, int(v)]
	var suffixes := ["K", "M", "B", "T", "Qa", "Qi"]
	var idx := -1
	while v >= 1000.0 and idx < suffixes.size() - 1:
		v /= 1000.0
		idx += 1
	return "%s%.2f%s" % [sign_s, v, suffixes[idx]]


# --- Building rows -----------------------------------------------------

func _build_upgrade_rows() -> void:
	if _gs == null:
		return
	for u in _gs.upgrades:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 54)
		btn.clip_text = true
		btn.autowrap_mode = TextServer.AUTOWRAP_OFF
		btn.add_theme_font_size_override("font_size", 15)
		var id: String = u["id"]
		btn.pressed.connect(func(): _buy_upgrade(id))
		_upgrades_list.add_child(btn)
		_upgrade_rows[id] = btn
	_refresh_upgrade_labels()


func _build_zone_rows() -> void:
	if _gs == null:
		return
	for child in _zones_list.get_children():
		child.queue_free()
	for i in range(_gs.zones.size()):
		var z: Dictionary = _gs.zones[i]
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)

		var title := Label.new()
		title.add_theme_font_size_override("font_size", 16)
		row.add_child(title)

		var story := Label.new()
		story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		story.add_theme_font_size_override("font_size", 13)
		story.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
		row.add_child(story)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 40)
		var zid: String = z["id"]
		btn.pressed.connect(func(): _unlock_or_enter_zone(zid))
		row.add_child(btn)

		var sep := HSeparator.new()
		row.add_child(sep)

		_zones_list.add_child(row)
	_refresh_zone_rows()


# --- Actions -----------------------------------------------------------

func _buy_upgrade(id: String) -> void:
	if _gs == null:
		return
	if _gs.buy_upgrade(id):
		_flash_button(_upgrade_rows.get(id))


func _unlock_or_enter_zone(zid: String) -> void:
	if _gs == null:
		return
	var z: Dictionary = _gs.get_zone(zid)
	if z.is_empty():
		return
	if z["unlocked"]:
		_gs.set_current_zone(zid)
	else:
		_gs.unlock_zone(zid)
	_refresh_zone_rows()


func _on_reset() -> void:
	if _save != null:
		_save.reset()
	_revealed_chapters = 1
	_refresh_all()
	_show_intro()


# --- Signal handlers ---------------------------------------------------

func _on_currency_changed(_gold: float, _essence: float) -> void:
	_refresh_affordability()


func _on_rates_changed(gps: float, eps: float) -> void:
	_income_label.text = "%s/s  •  %s ess/s" % [_fmt(gps), _fmt_small(eps)]


func _on_upgrade_bought(_id: String, _level: int) -> void:
	_refresh_upgrade_labels()


func _on_zone_unlocked(zone_id: String) -> void:
	var idx: int = _gs.get_zone_index(zone_id) if _gs != null else -1
	if idx >= 0:
		_revealed_chapters = max(_revealed_chapters, idx + 1)
	_refresh_zone_rows()
	_refresh_chapter()


func _on_offline_ready(gold: float, seconds: float) -> void:
	if gold <= 0.0:
		return
	var hours := int(seconds) / 3600
	var mins := (int(seconds) % 3600) / 60
	_offline_text.text = "While you were away (%dh %dm), your wanderer earned %s gold." % [
		hours, mins, _fmt(gold)
	]
	_offline_popup.visible = true


# --- Refreshers --------------------------------------------------------

func _refresh_all() -> void:
	if _gs == null:
		return
	# Recompute revealed chapters from unlocked zones.
	_revealed_chapters = 1
	for i in range(_gs.zones.size()):
		if _gs.zones[i]["unlocked"]:
			_revealed_chapters = max(_revealed_chapters, i + 1)
	_on_rates_changed(_gs.gold_per_sec, _gs.essence_per_sec)
	_refresh_upgrade_labels()
	_refresh_zone_rows()
	_refresh_chapter()


func _refresh_chapter() -> void:
	if _gs == null or _story == null:
		return
	var idx: int = _gs.get_zone_index(_gs.current_zone)
	if idx < 0:
		idx = 0
	var z: Dictionary = _gs.get_zone(_gs.current_zone)
	_zone_label.text = z.get("name", "Unknown") if not z.is_empty() else "Unknown"
	_chapter_label.text = "Ch. %d — %s" % [idx + 1, _story.get_chapter_text(idx)]


func _refresh_upgrade_labels() -> void:
	if _gs == null:
		return
	for u in _gs.upgrades:
		var btn: Button = _upgrade_rows.get(u["id"])
		if btn == null:
			continue
		var cost: float = _gs.upgrade_cost(u["id"])
		var effect_txt: String = _effect_text(u)
		btn.text = "%s  (Lv %d)\n%s   •   Cost: %s" % [
			u["name"], u["level"], effect_txt, _fmt(cost)
		]


func _effect_text(u: Dictionary) -> String:
	match u["category"]:
		"travel":
			return "+%d%% travel/lvl" % int(u["effect"] * 100.0)
		_:
			if u["id"] in ["essence_lens", "lucky_charm", "arcane_familiar"]:
				return "+%s essence/s/lvl" % _fmt_small(u["effect"])
			return "+%s gold/s/lvl" % _fmt_small(u["effect"])


func _fmt_small(value: float) -> String:
	if value >= 100.0:
		return _fmt(value)
	return "%.2f" % value


func _refresh_affordability() -> void:
	if _gs == null:
		return
	for u in _gs.upgrades:
		var btn: Button = _upgrade_rows.get(u["id"])
		if btn != null:
			btn.disabled = not _gs.can_afford(u["id"])


func _refresh_zone_rows() -> void:
	if _gs == null:
		return
	var rows := _zones_list.get_children()
	for i in range(min(rows.size(), _gs.zones.size())):
		var z: Dictionary = _gs.zones[i]
		var row := rows[i]
		var title := row.get_child(0) as Label
		var story := row.get_child(1) as Label
		var btn := row.get_child(2) as Button

		title.text = "%d. %s" % [i + 1, z["name"]]
		var is_current: bool = _gs.current_zone == z["id"]

		if z["unlocked"]:
			story.text = _story.get_chapter_text(i) if _story != null else ""
			story.visible = true
			if is_current:
				btn.text = "Current Chapter"
				btn.disabled = true
			else:
				btn.text = "Travel here"
				btn.disabled = false
		else:
			# Reveal story only up to the first locked zone as a teaser hidden.
			story.text = "??? — locked"
			story.visible = true
			btn.text = "Unlock — %s gold" % _fmt(z["unlock_cost"])
			btn.disabled = not _gs.can_afford_zone(z["id"])


# --- Overlays ----------------------------------------------------------

func _show_intro() -> void:
	if _story != null:
		_intro_text.text = _story.get_intro()
	_intro_overlay.visible = true


## Public toggles used by the on-screen action buttons (InputController).
func toggle_upgrades_panel() -> void:
	_toggle_panel(_upgrades_panel)


func toggle_story_panel() -> void:
	_toggle_panel(_zones_panel)


func _toggle_panel(panel: Panel) -> void:
	var to_show := not panel.visible
	_upgrades_panel.visible = false
	_zones_panel.visible = false
	panel.visible = to_show


func _flash_button(btn: Button) -> void:
	if btn == null:
		return
	var tween := create_tween()
	btn.modulate = Color(0.6, 1.0, 0.6)
	tween.tween_property(btn, "modulate", Color(1, 1, 1), 0.3)
