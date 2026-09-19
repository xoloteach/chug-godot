extends SceneTree
## Headless test suite for the idle-adventure game systems.
## Run with:
##   $GODOT --headless --script res://tests/test_systems.gd
##
## Instantiates GameState / StoryGenerator / SaveManager directly (preload +
## .new()) so the test is self-contained and does not depend on autoloads being
## present under --script.

const GameStateScript = preload("res://scripts/GameState.gd")
const StoryScript = preload("res://scripts/StoryGenerator.gd")
const SaveManagerScript = preload("res://scripts/SaveManager.gd")

var _failures := 0
var _checks := 0


func _initialize() -> void:
	print("=== Idle Adventure systems test ===")
	_test_income_ticks()
	_test_upgrade_scaling()
	_test_zone_multiplier()
	_test_save_roundtrip()
	_test_offline_progress()
	_test_new_game_flag()
	_test_story_determinism()

	print("=== %d checks, %d failures ===" % [_checks, _failures])
	if _failures == 0:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("TESTS FAILED")
		quit(1)


# --- assertion helpers -------------------------------------------------

func _check(cond: bool, label: String) -> void:
	_checks += 1
	if cond:
		print("PASS: %s" % label)
	else:
		_failures += 1
		print("FAIL: %s" % label)


func _make_game_state() -> Node:
	var gs = GameStateScript.new()
	# _ready() runs on tree entry; we call the definitions manually so the test
	# does not require a scene tree.
	gs._define_upgrades()
	gs._define_zones()
	gs.recompute_rates()
	return gs


# --- tests -------------------------------------------------------------

func _test_income_ticks() -> void:
	print("\n-- income accrual --")
	var gs := _make_game_state()
	var start_gold: float = gs.gold
	_check(gs.gold_per_sec > 0.0, "base gold_per_sec is positive")
	for i in range(10):
		gs.tick(1.0)
	_check(gs.gold > start_gold, "gold increased after 10s of ticks")
	_check(is_equal_approx(gs.gold, gs.gold_per_sec * 10.0), "gold matches rate * time")
	_check(gs.essence > 0.0, "essence accrued")
	gs.free()


func _test_upgrade_scaling() -> void:
	print("\n-- upgrade purchase + cost scaling --")
	var gs := _make_game_state()
	# Enough upgrades across categories?
	_check(gs.upgrades.size() >= 8, "at least 8 upgrades defined (%d)" % gs.upgrades.size())
	var cats := {}
	for u in gs.upgrades:
		cats[u["category"]] = true
	_check(cats.has("income") and cats.has("travel") and cats.has("gear") and cats.has("companions"),
		"upgrades span income/travel/gear/companions")

	gs.gold = 100000.0
	var rate_before: float = gs.gold_per_sec
	var cost1: float = gs.upgrade_cost("sharper_blade")
	var ok1: bool = gs.buy_upgrade("sharper_blade")
	_check(ok1, "bought sharper_blade")
	var cost2: float = gs.upgrade_cost("sharper_blade")
	_check(cost2 > cost1, "cost scales up after purchase (%.2f -> %.2f)" % [cost1, cost2])
	_check(is_equal_approx(cost2, cost1 * 1.15), "cost grows by ~1.15x")
	_check(gs.gold_per_sec > rate_before, "income rate increased after income upgrade")

	# Travel upgrade also boosts income via travel bonus.
	var rate_before_travel: float = gs.gold_per_sec
	gs.buy_upgrade("swift_boots")
	_check(gs.travel_speed > 1.0, "travel speed increased")
	_check(gs.gold_per_sec > rate_before_travel, "travel upgrade boosted income")
	gs.free()


func _test_zone_multiplier() -> void:
	print("\n-- zone unlock + multiplier --")
	var gs := _make_game_state()
	_check(gs.zones.size() >= 5, "at least 5 zones defined (%d)" % gs.zones.size())
	gs.buy_upgrade("sharper_blade") # give some flat income first
	gs.recompute_rates()
	var rate_before: float = gs.gold_per_sec
	gs.gold = 100000.0
	var ok: bool = gs.unlock_zone("emberpeak")
	_check(ok, "unlocked emberpeak")
	_check(gs.get_zone("emberpeak")["unlocked"], "emberpeak marked unlocked")
	_check(gs.current_zone == "emberpeak", "current zone switched to emberpeak")
	_check(gs.gold_per_sec > rate_before, "income multiplier applied (%.2f -> %.2f)" % [rate_before, gs.gold_per_sec])
	# Locked zone cannot be entered.
	_check(not gs.set_current_zone("voidgate"), "cannot enter locked zone")
	gs.free()


func _test_save_roundtrip() -> void:
	print("\n-- save/load round-trip --")
	var gs := _make_game_state()
	var story = StoryScript.new()
	story.generate(123456)
	var sm = SaveManagerScript.new()
	sm.game_state = gs
	sm.story = story

	gs.gold = 4242.0
	gs.essence = 88.0
	gs.buy_upgrade("loyal_hound")
	gs.gold = 100000.0
	gs.unlock_zone("emberpeak")
	gs.gold = 555.0

	var saved: bool = sm.save_game()
	_check(saved, "save_game wrote file")
	_check(FileAccess.file_exists("user://save.json"), "save.json exists in user://")

	# Fresh instances load the data.
	var gs2 := _make_game_state()
	var story2 = StoryScript.new()
	var sm2 = SaveManagerScript.new()
	sm2.game_state = gs2
	sm2.story = story2
	var loaded: bool = sm2.load_game()
	_check(loaded, "load_game read file")
	_check(is_equal_approx(gs2.gold, 555.0), "gold round-tripped (%.2f)" % gs2.gold)
	_check(gs2.get_upgrade("loyal_hound")["level"] == 1, "upgrade level round-tripped")
	_check(gs2.get_zone("emberpeak")["unlocked"], "zone unlock round-tripped")
	_check(gs2.current_zone == "emberpeak", "current zone round-tripped")
	_check(story2.seed_value == 123456, "story seed round-tripped")

	gs.free(); story.free(); sm.free()
	gs2.free(); story2.free(); sm2.free()


func _test_offline_progress() -> void:
	print("\n-- offline earnings --")
	var gs := _make_game_state()
	var story = StoryScript.new()
	story.generate(999)
	var sm = SaveManagerScript.new()
	sm.game_state = gs
	sm.story = story

	# Save with a last_saved timestamp two hours in the past.
	gs.gold = 0.0
	var rate: float = gs.gold_per_sec
	var data := sm.build_save_dict()
	data["last_saved"] = int(Time.get_unix_time_from_system()) - 7200 # 2h ago
	var f := FileAccess.open("user://save.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()

	var loaded: bool = sm.load_game()
	_check(loaded, "loaded save with past timestamp")
	var expected: float = rate * 7200.0 * 0.5
	_check(sm.offline_gold > 0.0, "offline gold granted (%.2f)" % sm.offline_gold)
	_check(is_equal_approx(sm.offline_gold, expected), "offline gold matches rate*time*0.5")
	_check(is_equal_approx(gs.gold, expected), "offline gold added to balance")

	# Clamp test: 20 hours ago should clamp to 8h.
	gs.gold = 0.0
	data["last_saved"] = int(Time.get_unix_time_from_system()) - (20 * 3600)
	var f2 := FileAccess.open("user://save.json", FileAccess.WRITE)
	f2.store_string(JSON.stringify(data))
	f2.close()
	sm.load_game()
	var clamped_expected: float = rate * (8.0 * 3600.0) * 0.5
	_check(is_equal_approx(sm.offline_seconds, 8.0 * 3600.0), "offline time clamped to 8h")
	_check(is_equal_approx(sm.offline_gold, clamped_expected), "clamped offline gold correct")

	gs.free(); story.free(); sm.free()


func _test_new_game_flag() -> void:
	print("\n-- is_new_game flag (intro vs welcome-back gating) --")
	# Ensure no stale save from earlier tests interferes with has_save().
	if FileAccess.file_exists("user://save.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))

	# Fresh SaveManager defaults to a new game before any load.
	var gs := _make_game_state()
	var story = StoryScript.new()
	story.generate(2024)
	var sm = SaveManagerScript.new()
	sm.game_state = gs
	sm.story = story
	_check(sm.is_new_game, "SaveManager defaults to is_new_game = true")

	# new_game() keeps it a new game and writes a save.
	sm.new_game()
	_check(FileAccess.file_exists("user://save.json"), "new_game wrote a save file")

	# A second SaveManager loading that existing save is NOT a new game.
	var gs2 := _make_game_state()
	var story2 = StoryScript.new()
	var sm2 = SaveManagerScript.new()
	sm2.game_state = gs2
	sm2.story = story2
	# Mimic _ready()'s branch: existing save -> loaded game.
	sm2.is_new_game = false
	var loaded: bool = sm2.load_game()
	_check(loaded, "loaded existing save")
	_check(not sm2.is_new_game, "loaded save reports is_new_game = false")

	# reset() wipes the save and flips back to a new game.
	sm2.reset()
	_check(sm2.is_new_game, "reset() sets is_new_game = true")

	gs.free(); story.free(); sm.free()
	gs2.free(); story2.free(); sm2.free()


func _test_story_determinism() -> void:
	print("\n-- story determinism --")
	var a = StoryScript.new()
	var b = StoryScript.new()
	var c = StoryScript.new()
	a.generate(42)
	b.generate(42)
	c.generate(43)

	_check(a.get_intro() == b.get_intro(), "same seed -> identical intro")
	_check(a.get_intro() != c.get_intro(), "different seed -> different intro")

	# Chapters are coherent and stable per seed.
	var stable := true
	for i in range(a.chapter_count()):
		if a.get_chapter_text(i) != b.get_chapter_text(i):
			stable = false
		_check(a.get_chapter_text(i) != "", "chapter %d has text" % i)
	_check(stable, "all chapters stable for a fixed seed")
	_check(a.chapter_count() >= 5, "at least 5 chapters (%d)" % a.chapter_count())

	a.free(); b.free(); c.free()
