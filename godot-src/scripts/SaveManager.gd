extends Node
## SaveManager: serializes GameState + story seed + last_saved time to JSON at
## user://save.json. Autosaves on a ~5s timer and on quit. On load, computes
## offline earnings (clamped to 8h) and exposes them for a welcome-back popup.
##
## user:// maps to browser storage (IndexedDB) in the Web export.

signal game_loaded()
signal game_saved()
signal offline_earnings_ready(gold: float, seconds: float)

const SAVE_PATH := "user://save.json"
const AUTOSAVE_INTERVAL := 5.0
const OFFLINE_MAX_SECONDS := 8.0 * 3600.0 # 8 hours
const OFFLINE_EFFICIENCY := 0.5
const SAVE_VERSION := 1

# Exposed for the UI welcome-back popup.
var offline_gold: float = 0.0
var offline_seconds: float = 0.0

# True when the last initialization started a brand-new game (no prior save),
# false when an existing save was loaded. The UI reads this on its own _ready()
# to decide between the origin-story intro (new game) and the welcome-back
# offline popup (returning player). reset() sets it true again.
var is_new_game: bool = true

var _autosave_timer: Timer

# References resolved at runtime (autoloads). Kept as vars so tests can inject.
var game_state: Node
var story: Node


func _ready() -> void:
	# Resolve sibling autoloads if present.
	if game_state == null and has_node("/root/GameState"):
		game_state = get_node("/root/GameState")
	if story == null and has_node("/root/StoryGenerator"):
		story = get_node("/root/StoryGenerator")

	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = AUTOSAVE_INTERVAL
	_autosave_timer.one_shot = false
	_autosave_timer.autostart = true
	add_child(_autosave_timer)
	_autosave_timer.timeout.connect(_on_autosave_timeout)

	if has_save():
		is_new_game = false
		load_game()
	else:
		is_new_game = true
		new_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		save_game()


func _on_autosave_timeout() -> void:
	save_game()


# --- Save / Load -------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func build_save_dict() -> Dictionary:
	var data := {
		"version": SAVE_VERSION,
		"last_saved": int(Time.get_unix_time_from_system()),
	}
	if game_state != null:
		data["game_state"] = game_state.to_dict()
	if story != null:
		data["story"] = story.to_dict()
	return data


func save_game() -> bool:
	if game_state == null:
		return false
	var data := build_save_dict()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot open save file for writing")
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	game_saved.emit()
	return true


func read_save_dict() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func load_game() -> bool:
	var data := read_save_dict()
	if data.is_empty():
		return false

	if story != null and data.has("story"):
		story.from_dict(data["story"])
	if game_state != null and data.has("game_state"):
		game_state.from_dict(data["game_state"])

	# Offline progress.
	var last_saved := int(data.get("last_saved", 0))
	_apply_offline_progress(last_saved)

	game_loaded.emit()
	return true


## Compute offline earnings from last_saved to now, clamped, and grant them.
func _apply_offline_progress(last_saved: int) -> void:
	offline_gold = 0.0
	offline_seconds = 0.0
	if game_state == null or last_saved <= 0:
		return
	var now := int(Time.get_unix_time_from_system())
	var elapsed: float = float(now - last_saved)
	if elapsed <= 0.0:
		return
	elapsed = min(elapsed, OFFLINE_MAX_SECONDS)
	offline_seconds = elapsed
	offline_gold = game_state.gold_per_sec * elapsed * OFFLINE_EFFICIENCY
	if offline_gold > 0.0:
		game_state.grant_gold(offline_gold)
	offline_earnings_ready.emit(offline_gold, offline_seconds)


# --- New game / reset --------------------------------------------------

func new_game() -> void:
	if game_state != null:
		game_state.reset()
	if story != null:
		story.new_random_story()
	offline_gold = 0.0
	offline_seconds = 0.0
	save_game()
	game_loaded.emit()


func reset() -> void:
	# Wipe the save file and start a brand new game.
	# Note: on the Web (user:// -> IndexedDB) backend a globalized
	# DirAccess.remove_absolute() is a no-op and pushes an error, so we just
	# overwrite the file with an empty object; new_game() then writes fresh state.
	if has_save():
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string("{}")
			f.close()
	is_new_game = true
	new_game()
