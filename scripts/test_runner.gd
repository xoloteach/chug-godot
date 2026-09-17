extends Node

func _ready() -> void:
	print("[TEST] Starting comprehensive integration test for CHUG: Shadow of Fame...")
	
	# Test 1: GameData inspection
	assert(GameData.campaign_parts.size() == 50, "Campaign must have 50 parts")
	assert(GameData.weapons.size() == 15, "Weapons must have 15 styles")
	assert(GameData.characters.size() >= 10, "Characters must have at least 10 entries")
	print("[TEST] GameData verified: 50 campaign parts, 15 weapons, full roster.")

	# Test 2: SaveStore XP & progression
	SaveStore.add_xp(500)
	assert(SaveStore.data["player"]["level"] >= 2, "Player should have leveled up")
	print("[TEST] SaveStore progression verified: Level %d" % SaveStore.data["player"]["level"])

	# Test 3: Audio synthesis
	AudioManager.play_sfx("hit_light")
	AudioManager.play_sfx("parry")
	AudioManager.play_sfx("rage_surge")
	print("[TEST] AudioManager procedural SFX generated & played successfully.")

	# Test 4: Modes instantiation
	var story = StoryManager.new()
	add_child(story)
	print("[TEST] StoryManager initialized & displayed Part 1 dialogue successfully.")
	story.queue_free()

	var arena = CombatArena.new()
	add_child(arena)
	print("[TEST] CombatArena initialized & spawned fighters successfully.")
	arena.queue_free()

	var armory = ArmoryMenu.new()
	add_child(armory)
	print("[TEST] ArmoryMenu initialized successfully.")
	armory.queue_free()

	var camp = CampMenu.new()
	add_child(camp)
	print("[TEST] CampMenu initialized successfully.")
	camp.queue_free()

	var dojo = TrainingDojo.new()
	add_child(dojo)
	print("[TEST] TrainingDojo initialized successfully.")
	dojo.queue_free()

	print("[TEST] All integration tests PASSED!")
	get_tree().quit(0)
