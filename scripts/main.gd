extends Node
class_name Main

## Main - Root Game Orchestrator & Scene Router for CHUG: Shadow of Fame

var current_view: Node = null

func _ready() -> void:
	GameSession.set_main_root(self)
	_switch_to_menu()

func on_game_mode_changed(_old_mode: GameSession.GameMode, new_mode: GameSession.GameMode) -> void:
	if current_view != null:
		current_view.queue_free()
		current_view = null

	match new_mode:
		GameSession.GameMode.MAIN_MENU:
			_switch_to_menu()
		GameSession.GameMode.STORY:
			_switch_to_story()
		GameSession.GameMode.COMBAT:
			_switch_to_combat()
		GameSession.GameMode.CAMP:
			_switch_to_camp()
		GameSession.GameMode.ARMORY:
			_switch_to_armory()
		GameSession.GameMode.TRAINING:
			_switch_to_training()
		_:
			_switch_to_menu()

func _switch_to_menu() -> void:
	var menu = MainMenu.new()
	add_child(menu)
	current_view = menu

func _switch_to_story() -> void:
	var story = StoryManager.new()
	add_child(story)
	current_view = story

func _switch_to_combat() -> void:
	var arena = CombatArena.new()
	add_child(arena)
	current_view = arena

func _switch_to_camp() -> void:
	var camp = CampMenu.new()
	add_child(camp)
	current_view = camp

func _switch_to_armory() -> void:
	var armory = ArmoryMenu.new()
	add_child(armory)
	current_view = armory

func _switch_to_training() -> void:
	var dojo = TrainingDojo.new()
	add_child(dojo)
	current_view = dojo
