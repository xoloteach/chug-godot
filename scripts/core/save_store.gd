extends Node

## SaveStore - Robust Save & Load Persistence Manager
## Handles player progression, stats, coins, gems, gear, inventory, unlocked roster, and camp upgrades.

const SAVE_PATH_DAT: String = "user://save_game.dat"
const SAVE_PATH_JSON: String = "user://save_game.json"

signal save_loaded
signal save_written
signal currency_changed(coins: int, gems: int)
signal level_up(new_level: int)

# Player Save Data Structure
var data: Dictionary = {
	"version": 1,
	"player": {
		"name": "Chug",
		"level": 1,
		"xp": 0,
		"coins": 200,
		"gems": 5,
		"stat_points": 2,
		"allocated_hp": 0,
		"allocated_atk": 0,
		"allocated_def": 0,
		"allocated_spd": 0,
		"allocated_crit": 0,
	},
	"equipment": {
		"equipped_character": "chug",
		"equipped_weapon": "fists",
		"equipped_armor": "",
		"equipped_helmet": "",
		"equipped_ranged": "",
		"equipped_magic": "",
		"weapon_stars": {
			"fists": 1
		}
	},
	"inventory": {
		"weapons": ["fists"],
		"armors": [],
		"helmets": [],
		"ranged": [],
		"magic": []
	},
	"progression": {
		"current_part": 1,
		"max_unlocked_part": 1,
		"completed_parts": [],
		"survival_high_score": 0,
		"tournament_rank": 1
	},
	"roster": {
		"unlocked": ["chug"],
		"active_squad": ["chug"]
	},
	"camp": {
		"forge_level": 1,
		"infirmary_level": 1,
		"dojo_level": 1,
		"tower_level": 1
	},
	"settings": {
		"sfx_volume": 1.0,
		"music_volume": 0.8,
		"crt_glitch_enabled": true,
		"touch_controls": false
	}
}

func _ready() -> void:
	load_game()

func save_game() -> bool:
	# Try binary file first
	var file = FileAccess.open(SAVE_PATH_DAT, FileAccess.WRITE)
	if file != null:
		file.store_var(data, true)
		file.close()
		save_written.emit()
		return true

	# Fallback to JSON
	var json_file = FileAccess.open(SAVE_PATH_JSON, FileAccess.WRITE)
	if json_file != null:
		var json_str = JSON.stringify(data, "\t")
		json_file.store_string(json_str)
		json_file.close()
		save_written.emit()
		return true
	
	push_error("SaveStore: Failed to write save data.")
	return false

func load_game() -> bool:
	# Check binary
	if FileAccess.file_exists(SAVE_PATH_DAT):
		var file = FileAccess.open(SAVE_PATH_DAT, FileAccess.READ)
		if file != null:
			var loaded = file.get_var(true)
			file.close()
			if loaded is Dictionary:
				_merge_data(loaded)
				save_loaded.emit()
				return true

	# Check JSON fallback
	if FileAccess.file_exists(SAVE_PATH_JSON):
		var json_file = FileAccess.open(SAVE_PATH_JSON, FileAccess.READ)
		if json_file != null:
			var text = json_file.get_as_text()
			json_file.close()
			var parsed = JSON.parse_string(text)
			if parsed is Dictionary:
				_merge_data(parsed)
				save_loaded.emit()
				return true

	# Brand new save
	save_game()
	save_loaded.emit()
	return true

func _merge_data(loaded: Dictionary) -> void:
	for section in loaded:
		if data.has(section) and loaded[section] is Dictionary:
			for key in loaded[section]:
				data[section][key] = loaded[section][key]
		else:
			data[section] = loaded[section]

func add_currency(coins_delta: int, gems_delta: int = 0) -> void:
	data["player"]["coins"] = max(0, data["player"]["coins"] + coins_delta)
	data["player"]["gems"] = max(0, data["player"]["gems"] + gems_delta)
	currency_changed.emit(data["player"]["coins"], data["player"]["gems"])
	save_game()

func add_xp(amount: int) -> void:
	var cur_lvl: int = data["player"]["level"]
	if cur_lvl >= GameData.MAX_LEVEL:
		return
	
	data["player"]["xp"] += amount
	var req = GameData.get_xp_for_level(cur_lvl)
	while data["player"]["xp"] >= req and data["player"]["level"] < GameData.MAX_LEVEL:
		data["player"]["xp"] -= req
		data["player"]["level"] += 1
		var pts = GameData.get_stat_points_awarded(data["player"]["level"])
		data["player"]["stat_points"] += pts
		level_up.emit(data["player"]["level"])
		req = GameData.get_xp_for_level(data["player"]["level"])
	
	save_game()

func allocate_stat(stat_name: String) -> bool:
	if data["player"]["stat_points"] <= 0:
		return false
	
	var key = "allocated_" + stat_name
	if not data["player"].has(key):
		return false
	
	data["player"][key] += 1
	data["player"]["stat_points"] -= 1
	save_game()
	return true

func unlock_weapon(weapon_id: String) -> bool:
	if not data["inventory"]["weapons"].has(weapon_id):
		data["inventory"]["weapons"].append(weapon_id)
		if not data["equipment"]["weapon_stars"].has(weapon_id):
			data["equipment"]["weapon_stars"][weapon_id] = 1
		save_game()
		return true
	return false

func equip_weapon(weapon_id: String) -> void:
	if data["inventory"]["weapons"].has(weapon_id):
		data["equipment"]["equipped_weapon"] = weapon_id
		save_game()

func unlock_character(char_id: String) -> void:
	if not data["roster"]["unlocked"].has(char_id):
		data["roster"]["unlocked"].append(char_id)
		save_game()

func complete_part(part_num: int) -> void:
	if not data["progression"]["completed_parts"].has(part_num):
		data["progression"]["completed_parts"].append(part_num)
	if part_num >= data["progression"]["max_unlocked_part"]:
		data["progression"]["max_unlocked_part"] = min(50, part_num + 1)
	data["progression"]["current_part"] = min(50, part_num + 1)
	
	# Check hero unlocks on specific parts
	if part_num == 4:
		unlock_character("yassine")
	elif part_num == 7:
		unlock_character("tora")
	elif part_num == 10:
		unlock_character("raevan")
	elif part_num == 14:
		unlock_character("sorya")
	elif part_num == 18:
		unlock_character("harjeev")
	elif part_num == 24:
		unlock_character("solo")
	elif part_num == 28:
		unlock_character("knight")
	elif part_num == 34:
		unlock_character("mr")
	elif part_num == 38:
		unlock_character("addy")
	
	save_game()

func get_calculated_stats() -> Dictionary:
	var p = data["player"]
	var eq = data["equipment"]
	var cur_char = eq["equipped_character"]
	var char_data = GameData.characters.get(cur_char, GameData.characters["chug"])
	
	var max_hp = GameData.BASE_HP + (p["allocated_hp"] * GameData.HP_PER_POINT)
	var atk = GameData.BASE_ATK + (p["allocated_atk"] * GameData.ATK_PER_POINT)
	var def = GameData.BASE_DEF + (p["allocated_def"] * GameData.DEF_FLAT_PER_POINT)
	var spd = GameData.BASE_SPD + (p["allocated_spd"] * GameData.SPD_PER_POINT)
	var crit_chance = GameData.BASE_CRIT_CHANCE + (p["allocated_crit"] * GameData.CRIT_CHANCE_PER_POINT)
	var crit_mult = GameData.BASE_CRIT_MULT + (p["allocated_crit"] * GameData.CRIT_MULT_PER_POINT)
	
	# Add weapon stats
	var wpn_id = eq["equipped_weapon"]
	if GameData.weapons.has(wpn_id):
		var w_info = GameData.weapons[wpn_id]
		var star = eq["weapon_stars"].get(wpn_id, 1)
		var star_mult = 1.0 + (star - 1) * 0.2
		atk += w_info["atk_bonus"] * star_mult
		spd *= w_info["speed_bonus"]
	
	# Add armor stats
	if GameData.armory.has(eq["equipped_armor"]):
		var arm = GameData.armory[eq["equipped_armor"]]
		max_hp += arm.get("hp", 0)
		def += arm.get("def", 0)
	
	# Add helmet stats
	if GameData.armory.has(eq["equipped_helmet"]):
		var helm = GameData.armory[eq["equipped_helmet"]]
		max_hp += helm.get("hp", 0)
		def += helm.get("def", 0)
	
	return {
		"max_hp": max_hp,
		"atk": atk,
		"def": def,
		"def_mitigation": p["allocated_def"] * GameData.DEF_MITIGATION_PER_POINT,
		"spd": spd,
		"crit_chance": crit_chance,
		"crit_mult": crit_mult,
		"aura_tier": GameData.get_aura_tier(p["level"])
	}
