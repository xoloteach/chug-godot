extends Node

## GameData - Master static definitions for CHUG: Shadow of Fame
## Contains movesets, armory catalog, 50-part campaign data, squad dossiers, and XP tables.

# XP Level Curve formula constants
const MAX_LEVEL: int = 50
const BASE_HP: float = 150.0
const HP_PER_POINT: float = 15.0
const BASE_ATK: float = 10.0
const ATK_PER_POINT: float = 1.5
const BASE_DEF: float = 0.0
const DEF_FLAT_PER_POINT: float = 1.0
const DEF_MITIGATION_PER_POINT: float = 0.005 # 0.5%
const BASE_SPD: float = 7.5
const SPD_PER_POINT: float = 0.15
const BASE_CRIT_CHANCE: float = 0.05 # 5%
const CRIT_CHANCE_PER_POINT: float = 0.0125 # 1.25%
const BASE_CRIT_MULT: float = 1.50
const CRIT_MULT_PER_POINT: float = 0.025 # 2.5%

# XP Table precomputed for 50 levels
var xp_table: Array[int] = []

# All 15 weapon definitions & movesets
var weapons: Dictionary = {}

# Equipment database (Armor, Helmets, Ranged, Magic)
var armory: Dictionary = {}

# Characters & Roster
var characters: Dictionary = {}

# Squad Synergies
var squad_synergies: Dictionary = {}

# 50-Part Campaign Scripture
var campaign_parts: Array[Dictionary] = []

# Ash Camp Upgrades & Perks
var camp_upgrades: Dictionary = {}

func _init() -> void:
	_init_xp_table()
	_init_weapons()
	_init_armory()
	_init_characters()
	_init_squad_synergies()
	_init_camp_upgrades()
	_init_campaign_parts()

func _init_xp_table() -> void:
	xp_table.clear()
	for l in range(1, MAX_LEVEL + 1):
		var req: int = 0
		if l <= 10:
			req = int(round(200.0 * pow(1.25, l - 1)))
		elif l <= 25:
			req = int(round(1860.0 * pow(1.18, l - 10)))
		else:
			req = int(round(22500.0 * pow(1.12, l - 25)))
		xp_table.append(req)

func get_xp_for_level(lvl: int) -> int:
	if lvl < 1:
		return xp_table[0]
	if lvl >= MAX_LEVEL:
		return xp_table[MAX_LEVEL - 1]
	return xp_table[lvl - 1]

func get_stat_points_awarded(lvl: int) -> int:
	if lvl <= 19:
		return 2
	elif lvl <= 39:
		return 3
	else:
		return 4

func get_aura_tier(lvl: int) -> int:
	if lvl < 10:
		return 0 # None
	elif lvl < 25:
		return 1 # Soft Cyan Pulse
	elif lvl < 40:
		return 2 # Shadow Flames
	else:
		return 3 # Golden Celestial Corona

func _init_weapons() -> void:
	weapons = {
		"fists": {
			"id": "fists",
			"name": "Brawler Fists",
			"category": "Unarmed",
			"price": 100,
			"rarity": "Common",
			"atk_bonus": 2,
			"speed_bonus": 1.05,
			"desc": "Raw street fighting fists. Fast, fluid, and deadly in close quarters.",
			"moves": [
				{"name": "Lead Jab", "input": "F", "dmg": 10, "startup": 4, "active": 3, "recovery": 6, "on_hit": 2, "type": "light", "reach": 42},
				{"name": "Straight Cross", "input": "F,F", "dmg": 16, "startup": 5, "active": 4, "recovery": 8, "on_hit": 1, "type": "light", "reach": 46},
				{"name": "Liver Hook", "input": "DF+F", "dmg": 18, "startup": 6, "active": 4, "recovery": 10, "on_hit": 3, "type": "light", "reach": 40},
				{"name": "Lead Uppercut", "input": "D+F", "dmg": 20, "startup": 7, "active": 4, "recovery": 11, "on_hit": "launch", "type": "heavy", "reach": 44},
				{"name": "Overhand Right", "input": "F+F", "dmg": 24, "startup": 9, "active": 5, "recovery": 14, "on_hit": "knockback", "type": "heavy", "reach": 52},
				{"name": "Low Shin Kick", "input": "K", "dmg": 11, "startup": 5, "active": 3, "recovery": 7, "on_hit": 0, "type": "kick", "reach": 45},
				{"name": "Mid Roundhouse", "input": "F+K", "dmg": 18, "startup": 7, "active": 4, "recovery": 11, "on_hit": 2, "type": "kick", "reach": 50},
				{"name": "Axe Kick", "input": "UF+K", "dmg": 25, "startup": 10, "active": 5, "recovery": 15, "on_hit": "overhead", "type": "kick", "reach": 48},
				{"name": "Sweep Kick", "input": "D+K", "dmg": 16, "startup": 6, "active": 4, "recovery": 12, "on_hit": "trip", "type": "kick", "reach": 55},
				{"name": "Shoulder Throw", "input": "G", "dmg": 35, "startup": 5, "active": 6, "recovery": 18, "on_hit": "throw", "type": "grab", "reach": 36}
			]
		},
		"daggers": {
			"id": "daggers",
			"name": "Void Daggers",
			"category": "Blades",
			"price": 250,
			"rarity": "Uncommon",
			"atk_bonus": 5,
			"speed_bonus": 1.15,
			"desc": "Twin short blades forged in shadow. Blistering attack speed.",
			"moves": [
				{"name": "Twin Thrust", "input": "F", "dmg": 12, "startup": 3, "active": 3, "recovery": 5, "on_hit": 4, "type": "light", "reach": 48},
				{"name": "Cross Slash", "input": "F,F", "dmg": 18, "startup": 4, "active": 4, "recovery": 7, "on_hit": 3, "type": "light", "reach": 50},
				{"name": "Shadow Step", "input": "F+F", "dmg": 15, "startup": 4, "active": 3, "recovery": 8, "on_hit": 3, "type": "dash_attack", "reach": 65},
				{"name": "Rising Dual Plunge", "input": "U+F", "dmg": 24, "startup": 6, "active": 5, "recovery": 12, "on_hit": "launch", "type": "heavy", "reach": 48},
				{"name": "Ankle Slicer", "input": "D+K", "dmg": 14, "startup": 4, "active": 3, "recovery": 6, "on_hit": "trip", "type": "kick", "reach": 52},
				{"name": "Shadow Flurry", "input": "F,F,F", "dmg": 30, "startup": 5, "active": 8, "recovery": 14, "on_hit": 2, "type": "combo", "reach": 55},
				{"name": "Reverse Disembowel", "input": "G", "dmg": 28, "startup": 5, "active": 8, "recovery": 16, "on_hit": "throw", "type": "grab", "reach": 38}
			]
		},
		"sais": {
			"id": "sais",
			"name": "Needle Sais",
			"category": "Piercing",
			"price": 500,
			"rarity": "Uncommon",
			"atk_bonus": 8,
			"speed_bonus": 1.10,
			"desc": "Triple-pronged defensive daggers engineered for parrying and penetrating armor.",
			"moves": [
				{"name": "Puncture Jab", "input": "F", "dmg": 13, "startup": 3, "active": 3, "recovery": 5, "on_hit": 3, "type": "light", "reach": 50},
				{"name": "Triple Needle Drill", "input": "F,F", "dmg": 20, "startup": 5, "active": 6, "recovery": 9, "on_hit": 3, "type": "light", "reach": 54},
				{"name": "Lunging Heart Impale", "input": "F+F", "dmg": 26, "startup": 7, "active": 5, "recovery": 13, "on_hit": "stagger", "type": "heavy", "reach": 62},
				{"name": "Spinning Sai Sweep", "input": "D+F", "dmg": 16, "startup": 5, "active": 4, "recovery": 8, "on_hit": "trip", "type": "kick", "reach": 50},
				{"name": "Rising Anti-Air Prong", "input": "U+F", "dmg": 24, "startup": 6, "active": 5, "recovery": 11, "on_hit": "launch", "type": "heavy", "reach": 48},
				{"name": "Throat Clamp Throw", "input": "G", "dmg": 32, "startup": 6, "active": 10, "recovery": 18, "on_hit": "throw", "type": "grab", "reach": 36}
			]
		},
		"batons": {
			"id": "batons",
			"name": "Twin Batons",
			"category": "Blunt",
			"price": 700,
			"rarity": "Rare",
			"atk_bonus": 12,
			"speed_bonus": 1.08,
			"desc": "Reinforced escrima sticks inflicting heavy concussive stagger.",
			"moves": [
				{"name": "Temple Strike", "input": "F", "dmg": 14, "startup": 4, "active": 4, "recovery": 6, "on_hit": 3, "type": "light", "reach": 52},
				{"name": "High-Low Pair", "input": "F,F", "dmg": 22, "startup": 5, "active": 5, "recovery": 9, "on_hit": 2, "type": "light", "reach": 55},
				{"name": "Overhead Skull Cracker", "input": "U+F", "dmg": 28, "startup": 8, "active": 6, "recovery": 14, "on_hit": "stun", "type": "heavy", "reach": 54},
				{"name": "Double Baton Sweep", "input": "D+F", "dmg": 18, "startup": 5, "active": 4, "recovery": 8, "on_hit": "trip", "type": "kick", "reach": 56},
				{"name": "Escrima Roll Finisher", "input": "F,F,F", "dmg": 38, "startup": 7, "active": 12, "recovery": 18, "on_hit": "wallbounce", "type": "combo", "reach": 58}
			]
		},
		"nunchaku": {
			"id": "nunchaku",
			"name": "Dragon Nunchaku",
			"category": "Flail",
			"price": 1000,
			"rarity": "Rare",
			"atk_bonus": 16,
			"speed_bonus": 1.12,
			"desc": "High velocity spinning hardwood flails with momentum loops.",
			"moves": [
				{"name": "Snap Whip", "input": "F", "dmg": 15, "startup": 4, "active": 4, "recovery": 6, "on_hit": 2, "type": "light", "reach": 54},
				{"name": "Figure-Eight Spin", "input": "F,F", "dmg": 24, "startup": 5, "active": 6, "recovery": 9, "on_hit": 4, "type": "light", "reach": 58},
				{"name": "Helicopter Overhead", "input": "U+F", "dmg": 28, "startup": 6, "active": 7, "recovery": 13, "on_hit": "launch", "type": "heavy", "reach": 56},
				{"name": "Low Chain Sweep", "input": "D+F", "dmg": 17, "startup": 5, "active": 4, "recovery": 8, "on_hit": "trip", "type": "kick", "reach": 58},
				{"name": "Dragon Storm Climax", "input": "F,F,F", "dmg": 40, "startup": 6, "active": 14, "recovery": 20, "on_hit": "launch", "type": "combo", "reach": 60}
			]
		},
		"kamas": {
			"id": "kamas",
			"name": "Twin Kamas",
			"category": "Sickles",
			"price": 1450,
			"rarity": "Rare",
			"atk_bonus": 20,
			"speed_bonus": 1.05,
			"desc": "Dual curved sickles built for flesh laceration and guard ripping.",
			"moves": [
				{"name": "Reaping Slash", "input": "F", "dmg": 16, "startup": 4, "active": 4, "recovery": 7, "on_hit": 2, "type": "light", "reach": 54},
				{"name": "Double Sickle Rend", "input": "F,F", "dmg": 26, "startup": 5, "active": 6, "recovery": 10, "on_hit": 3, "type": "light", "reach": 58},
				{"name": "Decapitate Scissor", "input": "U+F", "dmg": 32, "startup": 7, "active": 6, "recovery": 14, "on_hit": "knockdown", "type": "heavy", "reach": 56},
				{"name": "Low Tendon Hook", "input": "D+K", "dmg": 18, "startup": 5, "active": 4, "recovery": 8, "on_hit": "trip", "type": "kick", "reach": 60},
				{"name": "Blood Harvest Climax", "input": "F,F,F", "dmg": 44, "startup": 7, "active": 14, "recovery": 22, "on_hit": "bleed", "type": "combo", "reach": 62}
			]
		},
		"katana": {
			"id": "katana",
			"name": "Shadow Katana",
			"category": "Swords",
			"price": 1800,
			"rarity": "Epic",
			"atk_bonus": 25,
			"speed_bonus": 1.06,
			"desc": "Folded curved dark steel blade. Master of precision and iaido quick draws.",
			"moves": [
				{"name": "Iaido Quick Draw", "input": "F", "dmg": 18, "startup": 4, "active": 4, "recovery": 7, "on_hit": 3, "type": "light", "reach": 64},
				{"name": "Vertical Cleave", "input": "F,F", "dmg": 28, "startup": 6, "active": 6, "recovery": 12, "on_hit": "knockdown", "type": "heavy", "reach": 68},
				{"name": "Rising Moon Crescent", "input": "U+F", "dmg": 26, "startup": 5, "active": 5, "recovery": 11, "on_hit": "launch", "type": "heavy", "reach": 62},
				{"name": "Deep Heart Piercer", "input": "F+F", "dmg": 27, "startup": 7, "active": 5, "recovery": 13, "on_hit": "stagger", "type": "heavy", "reach": 74},
				{"name": "Low Shin Slicer", "input": "D+F", "dmg": 17, "startup": 5, "active": 4, "recovery": 8, "on_hit": "trip", "type": "kick", "reach": 65},
				{"name": "Shadow Step Decapitate", "input": "F,F,F", "dmg": 48, "startup": 7, "active": 16, "recovery": 24, "on_hit": "execute", "type": "combo", "reach": 78}
			]
		},
		"staff": {
			"id": "staff",
			"name": "Bo Staff",
			"category": "Polearm",
			"price": 2200,
			"rarity": "Epic",
			"atk_bonus": 28,
			"speed_bonus": 1.00,
			"desc": "Long reach hardwood staff dominating arena space and deflecting attacks.",
			"moves": [
				{"name": "Long Center Thrust", "input": "F", "dmg": 15, "startup": 5, "active": 4, "recovery": 7, "on_hit": 4, "type": "light", "reach": 85},
				{"name": "Double End Spin", "input": "F,F", "dmg": 24, "startup": 6, "active": 6, "recovery": 10, "on_hit": 2, "type": "light", "reach": 88},
				{"name": "Overhead Staff Slam", "input": "U+F", "dmg": 28, "startup": 7, "active": 6, "recovery": 13, "on_hit": "ground", "type": "heavy", "reach": 82},
				{"name": "360-Degree Floor Sweep", "input": "D+F", "dmg": 20, "startup": 6, "active": 5, "recovery": 10, "on_hit": "trip", "type": "kick", "reach": 90},
				{"name": "Dragon Whirlwind Finisher", "input": "F,F,F", "dmg": 46, "startup": 7, "active": 15, "recovery": 22, "on_hit": "launch", "type": "combo", "reach": 92}
			]
		},
		"scythe": {
			"id": "scythe",
			"name": "Death Scythe",
			"category": "Polearm",
			"price": 2650,
			"rarity": "Epic",
			"atk_bonus": 34,
			"speed_bonus": 0.95,
			"desc": "Massive harvesting curved blade with enormous reach and execute potential.",
			"moves": [
				{"name": "Harvesting Arc", "input": "F", "dmg": 20, "startup": 7, "active": 5, "recovery": 11, "on_hit": 2, "type": "light", "reach": 88},
				{"name": "Circle of Ruin", "input": "F,F", "dmg": 32, "startup": 8, "active": 7, "recovery": 15, "on_hit": "knockback", "type": "heavy", "reach": 92},
				{"name": "Guillotine Plunge", "input": "U+F", "dmg": 36, "startup": 9, "active": 6, "recovery": 18, "on_hit": "knockdown", "type": "heavy", "reach": 86},
				{"name": "Low Reaping Cut", "input": "D+F", "dmg": 22, "startup": 7, "active": 5, "recovery": 12, "on_hit": "trip", "type": "kick", "reach": 88},
				{"name": "Grim Reaper Eclipse", "input": "F,F,F", "dmg": 55, "startup": 9, "active": 16, "recovery": 26, "on_hit": "execute", "type": "combo", "reach": 96}
			]
		},
		"hammer": {
			"id": "hammer",
			"name": "Heavy War Hammer",
			"category": "Heavy Blunt",
			"price": 3100,
			"rarity": "Epic",
			"atk_bonus": 42,
			"speed_bonus": 0.88,
			"desc": "Monolithic slab of black iron. Super-armor hits that pulverize guards.",
			"moves": [
				{"name": "Horizontal Crush", "input": "F", "dmg": 26, "startup": 9, "active": 6, "recovery": 14, "on_hit": "knockback", "type": "light", "reach": 70},
				{"name": "Ground Shatter Slam", "input": "D+F", "dmg": 34, "startup": 11, "active": 7, "recovery": 18, "on_hit": "earthquake", "type": "heavy", "reach": 76},
				{"name": "Overhead Anvil Drop", "input": "U+F", "dmg": 42, "startup": 13, "active": 8, "recovery": 22, "on_hit": "flatten", "type": "heavy", "reach": 68},
				{"name": "Hammer Uppercut", "input": "UF+F", "dmg": 36, "startup": 11, "active": 6, "recovery": 19, "on_hit": "launch", "type": "heavy", "reach": 72},
				{"name": "Meteor Cataclysm", "input": "F,F,F", "dmg": 62, "startup": 12, "active": 18, "recovery": 28, "on_hit": "shatter", "type": "combo", "reach": 80}
			]
		},
		"claws": {
			"id": "claws",
			"name": "Shadow Claws",
			"category": "Fist Weapon",
			"price": 3600,
			"rarity": "Legendary",
			"atk_bonus": 38,
			"speed_bonus": 1.18,
			"desc": "Razor serrated steel gauntlets. Relentless savage bleeding rushes.",
			"moves": [
				{"name": "Predator Swipe", "input": "F", "dmg": 18, "startup": 3, "active": 3, "recovery": 6, "on_hit": 3, "type": "light", "reach": 46},
				{"name": "Cross Rend", "input": "F,F", "dmg": 28, "startup": 4, "active": 5, "recovery": 8, "on_hit": 4, "type": "light", "reach": 50},
				{"name": "Gore Pounce", "input": "U+F", "dmg": 35, "startup": 6, "active": 6, "recovery": 12, "on_hit": "knockdown", "type": "heavy", "reach": 60},
				{"name": "Beast Frenzy", "input": "F,F,F", "dmg": 52, "startup": 5, "active": 15, "recovery": 20, "on_hit": "bleed", "type": "combo", "reach": 58}
			]
		},
		"spear": {
			"id": "spear",
			"name": "Dragon Spear",
			"category": "Polearm",
			"price": 4200,
			"rarity": "Legendary",
			"atk_bonus": 44,
			"speed_bonus": 1.04,
			"desc": "Tipped with meteoric iron. Lethal mid-range wall carry capability.",
			"moves": [
				{"name": "Dragon Piercer", "input": "F", "dmg": 22, "startup": 5, "active": 4, "recovery": 8, "on_hit": 4, "type": "light", "reach": 90},
				{"name": "Dual Lance Thrust", "input": "F,F", "dmg": 34, "startup": 6, "active": 6, "recovery": 11, "on_hit": 3, "type": "heavy", "reach": 94},
				{"name": "Vaulting Vault Kick", "input": "U+F", "dmg": 38, "startup": 7, "active": 6, "recovery": 14, "on_hit": "launch", "type": "heavy", "reach": 85},
				{"name": "Sky Splitting Charge", "input": "F,F,F", "dmg": 58, "startup": 7, "active": 16, "recovery": 24, "on_hit": "wallbounce", "type": "combo", "reach": 98}
			]
		},
		"composite_sword": {
			"id": "composite_sword",
			"name": "Composite Greatsword",
			"category": "Hybrid",
			"price": 5000,
			"rarity": "Legendary",
			"atk_bonus": 50,
			"speed_bonus": 0.98,
			"desc": "Segmented mechanical blade that extends into a bladed whip.",
			"moves": [
				{"name": "Heavy Cleave", "input": "F", "dmg": 25, "startup": 6, "active": 5, "recovery": 10, "on_hit": 3, "type": "light", "reach": 75},
				{"name": "Whip Extension Arc", "input": "F,F", "dmg": 38, "startup": 7, "active": 7, "recovery": 13, "on_hit": "stagger", "type": "heavy", "reach": 100},
				{"name": "Spinning Segmented Storm", "input": "U+F", "dmg": 45, "startup": 8, "active": 8, "recovery": 16, "on_hit": "launch", "type": "heavy", "reach": 90},
				{"name": "Calamity Shredder", "input": "F,F,F", "dmg": 68, "startup": 8, "active": 18, "recovery": 26, "on_hit": "execute", "type": "combo", "reach": 105}
			]
		},
		"blood_reaper": {
			"id": "blood_reaper",
			"name": "Blood Reaper",
			"category": "Mythic",
			"price": 7500,
			"rarity": "Mythic",
			"atk_bonus": 62,
			"speed_bonus": 1.08,
			"desc": "Cursed crimson odachi feeding upon void energy. Heals user on critical hits.",
			"moves": [
				{"name": "Crimson Draw", "input": "F", "dmg": 28, "startup": 4, "active": 4, "recovery": 7, "on_hit": 4, "type": "light", "reach": 78},
				{"name": "Blood Cleave", "input": "F,F", "dmg": 42, "startup": 5, "active": 6, "recovery": 11, "on_hit": "bleed", "type": "heavy", "reach": 84},
				{"name": "Eclipse Guillotine", "input": "U+F", "dmg": 50, "startup": 7, "active": 7, "recovery": 15, "on_hit": "launch", "type": "heavy", "reach": 82},
				{"name": "Void Execution Dance", "input": "F,F,F", "dmg": 82, "startup": 6, "active": 20, "recovery": 28, "on_hit": "execute", "type": "combo", "reach": 90}
			]
		},
		"ak47": {
			"id": "ak47",
			"name": "AK-47 Void Fire",
			"category": "Firearm / Mythic",
			"price": 10000,
			"rarity": "Mythic",
			"atk_bonus": 75,
			"speed_bonus": 1.00,
			"desc": "Legendary anomaly firearm channeling rapid kinetic energy blasts.",
			"moves": [
				{"name": "Burst Fire 3-Round", "input": "F", "dmg": 30, "startup": 4, "active": 8, "recovery": 10, "on_hit": "knockback", "type": "ranged", "reach": 300},
				{"name": "Heavy Full Auto Spray", "input": "F,F", "dmg": 48, "startup": 6, "active": 16, "recovery": 16, "on_hit": "stagger", "type": "ranged", "reach": 320},
				{"name": "Rifle Butt Strike", "input": "U+F", "dmg": 26, "startup": 4, "active": 4, "recovery": 8, "on_hit": "launch", "type": "light", "reach": 50},
				{"name": "Suppressing Hellfire", "input": "F,F,F", "dmg": 95, "startup": 8, "active": 24, "recovery": 28, "on_hit": "knockdown", "type": "ranged", "reach": 350}
			]
		}
	}

func _init_armory() -> void:
	armory = {
		# Armor
		"armor_leather": {"id": "armor_leather", "name": "Shadow Leather Vest", "type": "armor", "price": 150, "hp": 50, "def": 5, "desc": "Lightweight padded leather for swift movement."},
		"armor_iron": {"id": "armor_iron", "name": "Reinforced Iron Cuirass", "type": "armor", "price": 450, "hp": 120, "def": 15, "desc": "Heavy iron chestplate deflecting sharp blows."},
		"armor_ash": {"id": "armor_ash", "name": "Ash Camp Guard Armor", "type": "armor", "price": 1100, "hp": 220, "def": 28, "desc": "Standard protective plate forged at the Ash sanctuary."},
		"armor_drakobane": {"id": "armor_drakobane", "name": "Drakobane Scale Hauberk", "type": "armor", "price": 2800, "hp": 380, "def": 45, "desc": "Treated scale armor granting immense resilience."},
		"armor_celestial": {"id": "armor_celestial", "name": "Celestial Void Aegis", "type": "armor", "price": 6500, "hp": 650, "def": 75, "desc": "Mythic chestplate pulsating with golden aura protection."},
		
		# Helmets
		"helm_cloth": {"id": "helm_cloth", "name": "Shadow Ninja Hood", "type": "helmet", "price": 100, "hp": 25, "def": 3, "desc": "Conceals identity and reduces wind resistance."},
		"helm_kabuto": {"id": "helm_kabuto", "name": "Iron Crest Kabuto", "type": "helmet", "price": 380, "hp": 70, "def": 10, "desc": "Traditional warrior helmet protecting from overhead chops."},
		"helm_ash": {"id": "helm_ash", "name": "Ash Camp Visor", "type": "helmet", "price": 950, "hp": 140, "def": 20, "desc": "Reinforced steel visor with glowing optical slot."},
		"helm_drakovisor": {"id": "helm_drakovisor", "name": "Drako Hunter Mask", "type": "helmet", "price": 2200, "hp": 240, "def": 32, "desc": "Imbued with anti-distortion shadow filter."},
		"helm_celestial": {"id": "helm_celestial", "name": "Crown of the Unseen", "type": "helmet", "price": 5200, "hp": 420, "def": 55, "desc": "Golden celestial crown sharpening perception."},

		# Ranged Items
		"ranged_shuriken": {"id": "ranged_shuriken", "name": "Shadow Shuriken", "type": "ranged", "price": 200, "atk": 15, "speed": 1.2, "cooldown": 4.0, "desc": "Fast 4-point throwing star."},
		"ranged_kunai": {"id": "ranged_kunai", "name": "Venom Kunai", "type": "ranged", "price": 600, "atk": 28, "speed": 1.0, "cooldown": 5.0, "desc": "Piercing throwing dagger with bleed damage."},
		"ranged_chakram": {"id": "ranged_chakram", "name": "Bladed Chakram", "type": "ranged", "price": 1500, "atk": 45, "speed": 0.9, "cooldown": 6.0, "desc": "Spinning circular blade hitting multiple times."},
		"ranged_bomb": {"id": "ranged_bomb", "name": "Void Smoke Bomb", "type": "ranged", "price": 3200, "atk": 70, "speed": 0.8, "cooldown": 8.0, "desc": "Explodes on impact, knocking enemies back."},

		# Relics / Magic
		"magic_fire_orb": {"id": "magic_fire_orb", "name": "Ember Spark Core", "type": "magic", "price": 500, "atk": 35, "desc": "Shoots a fireball causing burn ticks."},
		"magic_shadow_blast": {"id": "magic_shadow_blast", "name": "Void Shockwave Core", "type": "magic", "price": 1800, "atk": 65, "desc": "Releases an expanding dome of dark energy."},
		"magic_celestial_beam": {"id": "magic_celestial_beam", "name": "Golden Corona Beacon", "type": "magic", "price": 4500, "atk": 110, "desc": "Summons a devastating orbital beam of pure light."}
	}

func _init_characters() -> void:
	characters = {
		"chug": {
			"id": "chug", "name": "Chug", "role": "Lead Striker", "status": "playable",
			"default_weapon": "fists", "hp": 150, "atk": 12, "def": 0, "spd": 7.5,
			"desc": "The protagonist. Relentless shadow striker rebuilding his strength.",
			"synergy_title": "Relentless Will", "synergy_buff": "+15% Rage Generation"
		},
		"yassine": {
			"id": "yassine", "name": "Yassine", "role": "Fast Skirmisher", "status": "playable",
			"default_weapon": "sais", "hp": 135, "atk": 14, "def": 0, "spd": 8.5,
			"desc": "First companion rescued from Drako memory corruption. Rapid attacks.",
			"synergy_title": "Twin Flash", "synergy_buff": "+10% Attack Speed"
		},
		"tora": {
			"id": "tora", "name": "Tora", "role": "Iron Vanguard", "status": "playable",
			"default_weapon": "hammer", "hp": 220, "atk": 18, "def": 5, "spd": 6.2,
			"desc": "Unshakable juggernaut. Absorbs damage and breaks enemy guard.",
			"synergy_title": "Mountain Resolve", "synergy_buff": "+15% Maximum HP & Armor"
		},
		"raevan": {
			"id": "raevan", "name": "Raevan", "role": "Range Master", "status": "support",
			"default_weapon": "daggers", "hp": 130, "atk": 15, "def": 0, "spd": 8.0,
			"desc": "Disciplined archery and projectile master. Teaches tactical spacing.",
			"synergy_title": "Eagle Vision", "synergy_buff": "+12% Critical Strike Chance"
		},
		"sorya": {
			"id": "sorya", "name": "Sorya", "role": "Pressure Duelist", "status": "support",
			"default_weapon": "staff", "hp": 145, "atk": 16, "def": 2, "spd": 7.8,
			"desc": "Staff kata expert. Controls mid-range space and deflects projectiles.",
			"synergy_title": "Flow State", "synergy_buff": "+20% Parry Window Duration"
		},
		"harjeev": {
			"id": "harjeev", "name": "Harjeev", "role": "Camp Chronicler", "status": "camp",
			"default_weapon": "daggers", "hp": 140, "atk": 11, "def": 1, "spd": 7.5,
			"desc": "Records the names of all fallen and manages sanctuary resources.",
			"synergy_title": "Sanctuary Supply", "synergy_buff": "+25% Coin & XP Rewards"
		},
		"solo": {
			"id": "solo", "name": "Solo", "role": "Unchained Brawler", "status": "playable",
			"default_weapon": "claws", "hp": 170, "atk": 20, "def": 3, "spd": 8.0,
			"desc": "Liberated from Drako chain captivity. Ferocious close combat pressure.",
			"synergy_title": "Chain Breaker", "synergy_buff": "+15% Damage when below 40% HP"
		},
		"knight": {
			"id": "knight", "name": "Knight", "role": "Shield Vanguard", "status": "playable",
			"default_weapon": "composite_sword", "hp": 200, "atk": 19, "def": 8, "spd": 6.8,
			"desc": "Stalwart frontline anchor with impenetrable defenses.",
			"synergy_title": "Aegis Wall", "synergy_buff": "+20% Damage Mitigation on Block"
		},
		"mr": {
			"id": "mr", "name": "M.R", "role": "Shadow Strategist", "status": "tactician",
			"default_weapon": "kamas", "hp": 180, "atk": 22, "def": 4, "spd": 8.2,
			"desc": "Senior mentor with deep forbidden lore of the Unseen realm.",
			"synergy_title": "Grand Strategy", "synergy_buff": "+25% Super Finisher Damage"
		},
		"addy": {
			"id": "addy", "name": "Addy", "role": "Kinetic Scout", "status": "playable",
			"default_weapon": "nunchaku", "hp": 135, "atk": 17, "def": 1, "spd": 9.0,
			"desc": "Lightning fast scout and messenger crossing enemy lines.",
			"synergy_title": "Kinetic Momentum", "synergy_buff": "+15% Movement & Dash Speed"
		}
	}

func _init_squad_synergies() -> void:
	squad_synergies = {
		"speed_rush": {"name": "Speed Rush", "members": ["yassine", "addy"], "buff": "+20% Attack & Move Speed"},
		"iron_front": {"name": "Iron Wall", "members": ["tora", "knight"], "buff": "+25% Max HP & +10 Flat DEF"},
		"shadow_masters": {"name": "Shadow Council", "members": ["chug", "mr", "raevan"], "buff": "+25% Rage Rate & +15% Crit"}
	}

func _init_camp_upgrades() -> void:
	camp_upgrades = {
		"forge_tier": {"id": "forge_tier", "name": "Blacksmith Forge", "max_level": 5, "current": 1, "cost": 300, "desc": "Allows upgrading weapon star ratings up to Rank 5."},
		"infirmary": {"id": "infirmary", "name": "Camp Infirmary", "max_level": 5, "current": 1, "cost": 250, "desc": "Grants +5% passive HP regen and bonus max health."},
		"dojo_expansion": {"id": "dojo_expansion", "name": "Combat Dojo", "max_level": 5, "current": 1, "cost": 400, "desc": "Unlocks advanced combo techniques and training dummies."},
		"scout_tower": {"id": "scout_tower", "name": "Lookout Tower", "max_level": 5, "current": 1, "cost": 350, "desc": "Unlocks bonus bounty dispatches with rare rewards."}
	}

func _init_campaign_parts() -> void:
	campaign_parts.clear()
	
	# Full 50 parts initialized systematically with canonical script details
	var acts = [
		{"act": 1, "act_title": "The Awakening", "chapters": [
			{"ch": 1, "title": "THE FALL", "parts": [1, 2, 3, 4, 5]},
			{"ch": 2, "title": "VANISHED", "parts": [6, 7, 8, 9, 10]}
		]},
		{"act": 2, "act_title": "The Descent", "chapters": [
			{"ch": 3, "title": "FRACTURE", "parts": [11, 12, 13, 14, 15]},
			{"ch": 4, "title": "ASH CAMP", "parts": [16, 17, 18, 19, 20]}
		]},
		{"act": 3, "act_title": "The Broken Line", "chapters": [
			{"ch": 5, "title": "CAMPFIRE", "parts": [21, 22, 23, 24, 25]},
			{"ch": 6, "title": "RESCUE ARC", "parts": [26, 27, 28, 29, 30]}
		]},
		{"act": 4, "act_title": "The Shattered Gate", "chapters": [
			{"ch": 7, "title": "M.R ARRIVAL", "parts": [31, 32, 33, 34, 35]},
			{"ch": 8, "title": "BETRAYAL", "parts": [36, 37, 38, 39, 40]}
		]},
		{"act": 5, "act_title": "The War Gate", "chapters": [
			{"ch": 9, "title": "WAR DRUMS", "parts": [41, 42, 43, 44, 45]},
			{"ch": 10, "title": "WAR GATE", "parts": [46, 47, 48, 49, 50]}
		]}
	]

	# Build data for all 50 parts
	for act_info in acts:
		var act_num: int = act_info["act"]
		var act_name: String = act_info["act_title"]
		for ch_info in act_info["chapters"]:
			var ch_num: int = ch_info["ch"]
			var ch_name: String = ch_info["title"]
			for p_num in ch_info["parts"]:
				var p_data = _generate_part_data(act_num, act_name, ch_num, ch_name, p_num)
				campaign_parts.append(p_data)

func _generate_part_data(act: int, act_title: String, ch: int, ch_title: String, part: int) -> Dictionary:
	var coins_reward = 50 + (part * 35)
	var xp_reward = 20 + (part * 15)
	var env = "The Void"
	if act == 2:
		env = "Torii Gate Ruins"
	elif act == 3:
		env = "Ash Camp Mountains"
	elif act == 4:
		env = "Broken Line Fortress"
	elif act == 5:
		env = "War Gate Sunset Arena"

	var opponent_name = "Void Shadow"
	var opponent_weapon = "fists"
	var opponent_ai_tier = 1
	var opponent_hp = 120 + (part * 12)
	var opponent_atk = 10 + (part * 2)

	# Special boss milestones
	if part == 5:
		opponent_name = "Shadow Mirror Watcher"
		opponent_weapon = "daggers"
		opponent_ai_tier = 2
	elif part == 10:
		opponent_name = "Drako Enforcer Unit"
		opponent_weapon = "sais"
		opponent_ai_tier = 2
	elif part == 12:
		opponent_name = "Arowh - Drako No.12 (The Unkillable)"
		opponent_weapon = "hammer"
		opponent_ai_tier = 3
		opponent_hp = 1500
	elif part == 20:
		opponent_name = "Drako Ambush General"
		opponent_weapon = "batons"
		opponent_ai_tier = 3
	elif part == 25:
		opponent_name = "Varkul - Drako No.11 (The March)"
		opponent_weapon = "hammer"
		opponent_ai_tier = 3
	elif part == 26:
		opponent_name = "Zeigran - Drako No.10 (Heat Line)"
		opponent_weapon = "staff"
		opponent_ai_tier = 3
	elif part == 30:
		opponent_name = "Drako Warden Sentry"
		opponent_weapon = "kamas"
		opponent_ai_tier = 3
	elif part == 35:
		opponent_name = "Corrupted Phantom M.R"
		opponent_weapon = "katana"
		opponent_ai_tier = 4
	elif part == 37:
		opponent_name = "Dread Juno - Drako No.7 (Midnight Harvester)"
		opponent_weapon = "scythe"
		opponent_ai_tier = 4
	elif part == 40:
		opponent_name = "Kaith - Drako No.8 (Chain Field)"
		opponent_weapon = "claws"
		opponent_ai_tier = 4
	elif part == 45:
		opponent_name = "Rhaziel - Drako No.6 (Null Chapel)"
		opponent_weapon = "composite_sword"
		opponent_ai_tier = 4
	elif part == 50:
		opponent_name = "Xollonox — Gatekeeper of the Unseen"
		opponent_weapon = "blood_reaper"
		opponent_ai_tier = 5
		opponent_hp = 3000
		opponent_atk = 85

	var dialogues: Array[Dictionary] = []
	if part == 1:
		dialogues = [
			{"speaker": "CHUG", "text": "Too easy.", "glitch": false},
			{"speaker": "DONATION", "text": "You play for them… Play for me.", "glitch": true},
			{"speaker": "CHUG", "text": "…What? Who is that?", "glitch": false},
			{"speaker": "REFLECTION", "text": "The part of you that doesn't need them.", "glitch": true},
			{"speaker": "SYSTEM", "text": "[Chat freezes. Boundary shattered. Welcome to the Void.]", "glitch": true},
			{"speaker": "CHUG", "text": "…Hello? Bro? Where is my stream?", "glitch": false},
			{"speaker": "THE GUIDE", "text": "They are not here. Stand on your own feet.", "glitch": false}
		]
	elif part == 4:
		dialogues = [
			{"speaker": "CHUG", "text": "I see someone trapped in that crystal haze…", "glitch": false},
			{"speaker": "YASSINE", "text": "Chug? Is that really you? My hands… they feel numb.", "glitch": true},
			{"speaker": "THE GUIDE", "text": "Break the tether holding his spirit.", "glitch": false},
			{"speaker": "CHUG", "text": "Hang on, Yassine! I'm breaking you out!", "glitch": false}
		]
	elif part == 12:
		dialogues = [
			{"speaker": "AROWH", "text": "You swing like a mortal dreaming of applause. You cannot pierce this armor.", "glitch": false},
			{"speaker": "CHUG", "text": "I don't need applause to crack iron.", "glitch": false},
			{"speaker": "THE GUIDE", "text": "Warning: Damage mitigated by 95%. Survive the clock.", "glitch": true}
		]
	elif part == 21:
		dialogues = [
			{"speaker": "HARJEEV", "text": "The fire is lit. We survived another push through the valley.", "glitch": false},
			{"speaker": "TORA", "text": "More Drako squads are gathering near the pass.", "glitch": false},
			{"speaker": "CHUG", "text": "Let them come. We hold Ash Camp.", "glitch": false}
		]
	elif part == 50:
		dialogues = [
			{"speaker": "XOLLONOX", "text": "You climbed through fifty trials to reach the Gate of Fame.", "glitch": true},
			{"speaker": "CHUG", "text": "I'm not fighting for fame anymore.", "glitch": false},
			{"speaker": "XOLLONOX", "text": "Then prove that your shadow can outshine eternity!", "glitch": true},
			{"speaker": "THE GUIDE", "text": "FINAL CLASH. Release the Golden Celestial Corona!", "glitch": true}
		]
	else:
		dialogues = [
			{"speaker": "THE GUIDE", "text": "Act %d · Part %d — The shadow deepens ahead." % [act, part], "glitch": false},
			{"speaker": "CHUG", "text": "Another Drako unit blocking the path. Time to clear them out.", "glitch": false},
			{"speaker": opponent_name.to_upper(), "text": "You will advance no further, Chug!", "glitch": (part % 3 == 0)}
		]

	return {
		"part": part,
		"act": act,
		"act_title": act_title,
		"chapter": ch,
		"chapter_title": ch_title,
		"environment": env,
		"rewards": {"coins": coins_reward, "xp": xp_reward, "gems": 1 if part % 5 == 0 else 0},
		"opponent": {
			"name": opponent_name,
			"weapon": opponent_weapon,
			"hp": opponent_hp,
			"atk": opponent_atk,
			"ai_tier": opponent_ai_tier
		},
		"dialogues": dialogues
	}
