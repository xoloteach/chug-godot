extends Node

## VisualTestCapture - Uses dedicated SubViewport to render & capture all game scenes

var sub_viewport: SubViewport
var main_root: Main
var current_step: int = 0
var step_frames: int = 0

func _ready() -> void:
	print("[VISION TEST] Initializing SubViewport renderer (1280x720)...")
	sub_viewport = SubViewport.new()
	sub_viewport.size = Vector2i(1280, 720)
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(sub_viewport)

	main_root = Main.new()
	sub_viewport.add_child(main_root)

func _physics_process(_delta: float) -> void:
	step_frames += 1

	match current_step:
		0:
			if step_frames >= 20:
				_save_capture("01_main_menu.png")
				current_step = 1
				step_frames = 0
				GameSession.start_story_part(1)
		1:
			if step_frames >= 20:
				_save_capture("02_story_cutscene.png")
				current_step = 2
				step_frames = 0
				GameSession.launch_combat({
					"opponent": {
						"name": "Drako Shadow Enforcer",
						"weapon": "katana",
						"hp": 250,
						"atk": 18,
						"ai_tier": 2
					},
					"environment": "Torii Gate Ruins"
				})
		2:
			if step_frames >= 25:
				if main_root.current_view is CombatArena:
					var arena = main_root.current_view as CombatArena
					if arena.player != null:
						arena.player._try_perform_attack("heavy")
				_save_capture("03_combat_arena.png")
				current_step = 3
				step_frames = 0
		3:
			if step_frames >= 20:
				if main_root.current_view is CombatArena:
					var arena = main_root.current_view as CombatArena
					if arena.player != null:
						arena.player.current_rage = 100.0
						arena.player.aura_tier = 3
						arena.player._try_activate_rage()
				_save_capture("04_combat_rage_mode.png")
				current_step = 4
				step_frames = 0
				GameSession.open_armory()
		4:
			if step_frames >= 20:
				_save_capture("05_armory_menu.png")
				current_step = 5
				step_frames = 0
				GameSession.open_camp()
		5:
			if step_frames >= 20:
				_save_capture("06_camp_menu.png")
				current_step = 6
				step_frames = 0
				GameSession.start_training()
		6:
			if step_frames >= 20:
				_save_capture("07_training_dojo.png")
				current_step = 7
				step_frames = 0
		7:
			print("[VISION TEST] All 7 viewport captures generated successfully!")
			get_tree().quit(0)

func _save_capture(filename: String) -> void:
	var tex = sub_viewport.get_texture()
	if tex != null:
		var img = tex.get_image()
		if img != null and not img.is_empty():
			var path = "tests/screenshots/" + filename
			var err = img.save_png(path)
			if err == OK:
				print("[CAPTURE] Saved: %s (%dx%d)" % [path, img.get_width(), img.get_height()])
			else:
				push_error("Failed to save image to " + path)
