extends Node

## GameSession - Runtime State Machine & Scene Router
## Controls game transitions between Main Menu, Story Mode, Combat Arena, Ash Camp, Armory, and Training.

signal state_changed(old_state: String, new_state: String)
signal fight_completed(won: bool, stats: Dictionary)

enum GameMode {
	NONE,
	MAIN_MENU,
	STORY,
	COMBAT,
	CAMP,
	ARMORY,
	TRAINING,
	SURVIVAL,
	TOURNAMENT
}

var current_mode: GameMode = GameMode.MAIN_MENU
var current_story_part: int = 1
var active_encounter_data: Dictionary = {}
var survival_streak: int = 0
var tournament_round: int = 1

# Root UI / Scene references
var current_scene_node: Node = null
var main_root: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_main_root(root: Node) -> void:
	main_root = root

func start_story_part(part_num: int) -> void:
	current_story_part = clamp(part_num, 1, 50)
	var p_data = GameData.campaign_parts[current_story_part - 1]
	active_encounter_data = p_data
	change_mode(GameMode.STORY)

func launch_combat(encounter: Dictionary) -> void:
	active_encounter_data = encounter
	change_mode(GameMode.COMBAT)

func start_training() -> void:
	change_mode(GameMode.TRAINING)

func open_camp() -> void:
	change_mode(GameMode.CAMP)

func open_armory() -> void:
	change_mode(GameMode.ARMORY)

func return_to_main_menu() -> void:
	change_mode(GameMode.MAIN_MENU)

func change_mode(new_mode: GameMode) -> void:
	var old = current_mode
	current_mode = new_mode
	
	if main_root != null and main_root.has_method("on_game_mode_changed"):
		main_root.on_game_mode_changed(old, new_mode)
	
	state_changed.emit(str(old), str(new_mode))

func on_combat_finished(won: bool, combat_stats: Dictionary) -> void:
	if won:
		if active_encounter_data.has("rewards"):
			var rew = active_encounter_data["rewards"]
			SaveStore.add_currency(rew.get("coins", 0), rew.get("gems", 0))
			SaveStore.add_xp(rew.get("xp", 0))
		
		if active_encounter_data.has("part"):
			SaveStore.complete_part(active_encounter_data["part"])
		
		if current_mode == GameMode.SURVIVAL:
			survival_streak += 1
			if survival_streak > SaveStore.data["progression"]["survival_high_score"]:
				SaveStore.data["progression"]["survival_high_score"] = survival_streak
				SaveStore.save_game()
	else:
		if current_mode == GameMode.SURVIVAL:
			survival_streak = 0
	
	fight_completed.emit(won, combat_stats)
