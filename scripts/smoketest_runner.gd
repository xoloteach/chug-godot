extends Node

## SmokeTestRunner - Multi-stage automated validation suite for CHUG: Shadow of Fame

var test_results: Array[Dictionary] = []

func _ready() -> void:
	print("=========================================================")
	print("  STARTING SMOKE TEST SUITE: CHUG - SHADOW OF FAME       ")
	print("=========================================================")
	
	_run_test("Singletons Autoload Verification", _test_singletons)
	_run_test("GameData & Armory Database Integrity", _test_gamedata)
	_run_test("50-Part Story Scripture & Campaign Flow", _test_campaign_scripture)
	_run_test("Audio Manager & Asset Fallback Synthesis", _test_audio_system)
	_run_test("SaveStore Persistence & XP Curve Scaling", _test_savestore)
	_run_test("Combat Physics, States & Hitbox Resolution", _test_combat_simulation)
	_run_test("UI Hierarchy & Scene Lifecycle", _test_scene_lifecycle)
	_run_test("End-to-End GameMode Transitions", _test_mode_transitions)
	
	_print_summary()

func _run_test(test_name: String, test_callable: Callable) -> void:
	print("[RUNNING] %s..." % test_name)
	var start_time = Time.get_ticks_msec()
	var success = true
	var err_msg = ""
	
	var err = test_callable.call()
	if err is String and err != "":
		success = false
		err_msg = err
	
	var elapsed = Time.get_ticks_msec() - start_time
	test_results.append({
		"name": test_name,
		"passed": success,
		"time_ms": elapsed,
		"error": err_msg
	})
	
	if success:
		print("  -> PASSED (%d ms)" % elapsed)
	else:
		print("  -> FAILED: %s" % err_msg)

func _test_singletons() -> String:
	if GameData == null: return "GameData singleton is null"
	if SaveStore == null: return "SaveStore singleton is null"
	if GameSession == null: return "GameSession singleton is null"
	if AudioManager == null: return "AudioManager singleton is null"
	return ""

func _test_gamedata() -> String:
	if GameData.weapons.size() != 15:
		return "Expected 15 weapons, found %d" % GameData.weapons.size()
	
	for w_id in GameData.weapons:
		var w = GameData.weapons[w_id]
		if not w.has("moves") or w["moves"].is_empty():
			return "Weapon %s has no moveset" % w_id
	
	if GameData.characters.size() < 10:
		return "Expected at least 10 character dossiers, found %d" % GameData.characters.size()
	
	if GameData.armory.is_empty():
		return "Armory catalog is empty"
	
	return ""

func _test_campaign_scripture() -> String:
	if GameData.campaign_parts.size() != 50:
		return "Expected exactly 50 campaign parts, found %d" % GameData.campaign_parts.size()
	
	for i in range(50):
		var p = GameData.campaign_parts[i]
		if p.get("part") != (i + 1):
			return "Part mismatch at index %d (got part %s)" % [i, p.get("part")]
		if not p.has("opponent") or not p.has("rewards") or not p.has("dialogues"):
			return "Part %d missing opponent, rewards, or dialogues" % (i + 1)
	
	return ""

func _test_audio_system() -> String:
	AudioManager.play_sfx("hit_light")
	AudioManager.play_sfx("hit_heavy")
	AudioManager.play_sfx("slash")
	AudioManager.play_sfx("parry")
	AudioManager.play_sfx("whoosh")
	AudioManager.play_sfx("rage_surge")
	AudioManager.play_sfx("ui_click")
	AudioManager.play_sfx("ko")
	AudioManager.play_music("story")
	AudioManager.play_music("combat")
	AudioManager.play_music("camp")
	AudioManager.stop_music()
	return ""

func _test_savestore() -> String:
	var initial_lvl = SaveStore.data["player"]["level"]
	SaveStore.add_xp(600)
	if SaveStore.data["player"]["level"] <= initial_lvl:
		return "Player level did not increase after XP addition"
	
	var initial_pts = SaveStore.data["player"]["stat_points"]
	if initial_pts > 0:
		SaveStore.allocate_stat("hp")
		if SaveStore.data["player"]["stat_points"] != (initial_pts - 1):
			return "Stat points allocation failed"
	
	SaveStore.unlock_weapon("katana")
	SaveStore.equip_weapon("katana")
	if SaveStore.data["equipment"]["equipped_weapon"] != "katana":
		return "Equip weapon failed"
	
	SaveStore.complete_part(1)
	if not SaveStore.data["progression"]["completed_parts"].has(1):
		return "Campaign part completion not saved"
	
	var stats = SaveStore.get_calculated_stats()
	if stats["max_hp"] <= 0 or stats["atk"] <= 0:
		return "Calculated stats invalid"
	
	return ""

func _test_combat_simulation() -> String:
	var p = Fighter.new()
	p.is_player = true
	p.character_id = "chug"
	p.weapon_id = "fists"
	add_child(p)

	var e = Fighter.new()
	e.is_player = false
	e.character_id = "drakov"
	e.weapon_id = "daggers"
	e.max_hp = 100.0
	e.current_hp = 100.0
	add_child(e)

	p.opponent = e
	e.opponent = p

	# Simulate attack frame ticks
	p._start_attack_move({"name": "Test Jab", "dmg": 20, "startup": 2, "active": 2, "recovery": 4, "on_hit": 0})
	
	for frame in range(10):
		p._physics_process(1.0 / 60.0)
		e._physics_process(1.0 / 60.0)
	
	# Simulate hit registration
	var dummy_hitbox = Hitbox.new()
	dummy_hitbox.attacker = p
	dummy_hitbox.damage = 25.0
	e.take_hit(dummy_hitbox)
	
	if e.current_hp >= 100.0:
		p.queue_free()
		e.queue_free()
		dummy_hitbox.queue_free()
		return "Enemy took no damage from hitbox"

	p.queue_free()
	e.queue_free()
	dummy_hitbox.queue_free()
	return ""

func _test_scene_lifecycle() -> String:
	var scenes_to_test = [
		MainMenu.new(),
		StoryManager.new(),
		CombatArena.new(),
		ArmoryMenu.new(),
		CampMenu.new(),
		TrainingDojo.new()
	]

	for sc in scenes_to_test:
		add_child(sc)
		sc.queue_free()
	
	return ""

func _test_mode_transitions() -> String:
	var root_main = Main.new()
	add_child(root_main)
	
	GameSession.open_camp()
	GameSession.open_armory()
	GameSession.start_training()
	GameSession.start_story_part(1)
	GameSession.return_to_main_menu()
	
	root_main.queue_free()
	return ""

func _print_summary() -> void:
	var total = test_results.size()
	var passed_count = 0
	
	print("=========================================================")
	print("                    SMOKE TEST SUMMARY                   ")
	print("=========================================================")
	
	for res in test_results:
		var status_str = "[PASS]" if res["passed"] else "[FAIL]"
		if res["passed"]: passed_count += 1
		print("%s %s (%d ms)" % [status_str, res["name"], res["time_ms"]])
	
	print("=========================================================")
	print("  TOTAL TESTS: %d | PASSED: %d | FAILED: %d" % [total, passed_count, total - passed_count])
	print("=========================================================")
	
	if passed_count == total:
		print(" ALL SMOKE TESTS COMPLETED WITH 100% SUCCESS!")
		get_tree().quit(0)
	else:
		print(" SOME SMOKE TESTS FAILED!")
		get_tree().quit(1)
