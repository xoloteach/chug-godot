extends Node
## GameState: the economy brain of the idle adventure.
## Holds currencies (gold, essence), income rates, upgrades and zones/chapters.
## Pure logic so it can be unit tested headlessly. Emits signals for the UI.

signal currency_changed(gold: float, essence: float)
signal upgrade_bought(upgrade_id: String, new_level: int)
signal zone_unlocked(zone_id: String)
signal rates_changed(gold_per_sec: float, essence_per_sec: float)

# --- Currencies ---
var gold: float = 0.0
var essence: float = 0.0

# --- Derived income rates (recomputed from upgrades + current zone) ---
var gold_per_sec: float = 0.0
var essence_per_sec: float = 0.0

# --- Base rates before multipliers ---
const BASE_GOLD_PER_SEC := 1.0
const BASE_ESSENCE_PER_SEC := 0.05

# Travel speed influences how fast the hero explores; it also boosts income
# a little because faster exploration means more encounters.
var travel_speed: float = 1.0

# Which zone/chapter the hero is currently in.
var current_zone: String = "greenwood"

# Upgrades: at least 8 across categories income/travel/gear/companions.
# Each entry: id, name, category, base_cost, cost_growth, effect, level.
# "effect" is the per-level bonus interpreted by recompute_rates().
var upgrades: Array = []

# Zones/chapters: at least 5 that unlock in sequence.
# Each: id, name, unlock_cost, income_multiplier, unlocked, story hook via index.
var zones: Array = []


func _ready() -> void:
	_define_upgrades()
	_define_zones()
	recompute_rates()


func _define_upgrades() -> void:
	upgrades = [
		# --- Income category ---
		{
			"id": "sharper_blade",
			"name": "Sharper Blade",
			"category": "income",
			"base_cost": 15.0,
			"cost_growth": 1.15,
			"effect": 0.75, # +gold/sec per level
			"level": 0,
		},
		{
			"id": "coin_purse",
			"name": "Enchanted Coin Purse",
			"category": "income",
			"base_cost": 100.0,
			"cost_growth": 1.15,
			"effect": 4.0,
			"level": 0,
		},
		{
			"id": "essence_lens",
			"name": "Essence Lens",
			"category": "income",
			"base_cost": 60.0,
			"cost_growth": 1.15,
			"effect": 0.15, # +essence/sec per level
			"level": 0,
		},
		# --- Travel speed category ---
		{
			"id": "swift_boots",
			"name": "Swift Boots",
			"category": "travel",
			"base_cost": 50.0,
			"cost_growth": 1.15,
			"effect": 0.10, # +travel speed per level
			"level": 0,
		},
		{
			"id": "windrunner_cloak",
			"name": "Windrunner Cloak",
			"category": "travel",
			"base_cost": 250.0,
			"cost_growth": 1.15,
			"effect": 0.20,
			"level": 0,
		},
		# --- Gear category ---
		{
			"id": "sturdy_armor",
			"name": "Sturdy Armor",
			"category": "gear",
			"base_cost": 120.0,
			"cost_growth": 1.15,
			"effect": 2.0, # +gold/sec per level (survives longer, loots more)
			"level": 0,
		},
		{
			"id": "lucky_charm",
			"name": "Lucky Charm",
			"category": "gear",
			"base_cost": 400.0,
			"cost_growth": 1.15,
			"effect": 0.30, # +essence/sec per level
			"level": 0,
		},
		# --- Companions category ---
		{
			"id": "loyal_hound",
			"name": "Loyal Hound",
			"category": "companions",
			"base_cost": 200.0,
			"cost_growth": 1.15,
			"effect": 3.0, # +gold/sec per level
			"level": 0,
		},
		{
			"id": "arcane_familiar",
			"name": "Arcane Familiar",
			"category": "companions",
			"base_cost": 800.0,
			"cost_growth": 1.15,
			"effect": 0.50, # +essence/sec per level
			"level": 0,
		},
	]


func _define_zones() -> void:
	zones = [
		{
			"id": "greenwood",
			"name": "The Greenwood Vale",
			"unlock_cost": 0.0,
			"income_multiplier": 1.0,
			"unlocked": true,
		},
		{
			"id": "emberpeak",
			"name": "Emberpeak Foothills",
			"unlock_cost": 500.0,
			"income_multiplier": 1.6,
			"unlocked": false,
		},
		{
			"id": "sunkencrypt",
			"name": "The Sunken Crypt",
			"unlock_cost": 2500.0,
			"income_multiplier": 2.5,
			"unlocked": false,
		},
		{
			"id": "frostspire",
			"name": "Frostspire Reaches",
			"unlock_cost": 12000.0,
			"income_multiplier": 4.0,
			"unlocked": false,
		},
		{
			"id": "voidgate",
			"name": "The Voidgate Citadel",
			"unlock_cost": 60000.0,
			"income_multiplier": 7.0,
			"unlocked": false,
		},
	]


# --- Lookups -----------------------------------------------------------

func get_upgrade(upgrade_id: String) -> Dictionary:
	for u in upgrades:
		if u["id"] == upgrade_id:
			return u
	return {}


func get_zone(zone_id: String) -> Dictionary:
	for z in zones:
		if z["id"] == zone_id:
			return z
	return {}


func get_zone_index(zone_id: String) -> int:
	for i in range(zones.size()):
		if zones[i]["id"] == zone_id:
			return i
	return -1


# --- Costs -------------------------------------------------------------

## Current cost of the next level of an upgrade: base_cost * growth^level.
func upgrade_cost(upgrade_id: String) -> float:
	var u := get_upgrade(upgrade_id)
	if u.is_empty():
		return INF
	return u["base_cost"] * pow(u["cost_growth"], u["level"])


func can_afford(upgrade_id: String) -> bool:
	return gold >= upgrade_cost(upgrade_id)


func can_afford_zone(zone_id: String) -> bool:
	var z := get_zone(zone_id)
	if z.is_empty():
		return false
	return gold >= z["unlock_cost"]


# --- Actions -----------------------------------------------------------

## Purchase one level of an upgrade. Returns true on success.
func buy_upgrade(upgrade_id: String) -> bool:
	var u := get_upgrade(upgrade_id)
	if u.is_empty():
		return false
	var cost := upgrade_cost(upgrade_id)
	if gold < cost:
		return false
	gold -= cost
	u["level"] += 1
	recompute_rates()
	upgrade_bought.emit(upgrade_id, u["level"])
	currency_changed.emit(gold, essence)
	return true


## Unlock the next zone (spends gold). Returns true on success.
func unlock_zone(zone_id: String) -> bool:
	var z := get_zone(zone_id)
	if z.is_empty() or z["unlocked"]:
		return false
	if gold < z["unlock_cost"]:
		return false
	gold -= z["unlock_cost"]
	z["unlocked"] = true
	current_zone = zone_id
	recompute_rates()
	zone_unlocked.emit(zone_id)
	currency_changed.emit(gold, essence)
	return true


## Switch to an already-unlocked zone.
func set_current_zone(zone_id: String) -> bool:
	var z := get_zone(zone_id)
	if z.is_empty() or not z["unlocked"]:
		return false
	current_zone = zone_id
	recompute_rates()
	return true


# --- Rates -------------------------------------------------------------

## Recompute income rates from upgrades, travel speed and current zone.
func recompute_rates() -> void:
	var gold_flat := BASE_GOLD_PER_SEC
	var essence_flat := BASE_ESSENCE_PER_SEC
	travel_speed = 1.0

	for u in upgrades:
		var contribution: float = u["effect"] * u["level"]
		match u["category"]:
			"travel":
				travel_speed += contribution
			"income", "gear", "companions":
				# Split by which currency the effect targets. We infer from
				# magnitude/category: essence effects are the small fractional
				# ones tagged by id, everything else is gold. Keep it explicit.
				if u["id"] in ["essence_lens", "lucky_charm", "arcane_familiar"]:
					essence_flat += contribution
				else:
					gold_flat += contribution

	var zone := get_zone(current_zone)
	var mult: float = zone.get("income_multiplier", 1.0) if not zone.is_empty() else 1.0

	# Travel speed gives a modest income bonus (faster exploration => more loot).
	var travel_bonus := 1.0 + (travel_speed - 1.0) * 0.5

	gold_per_sec = gold_flat * mult * travel_bonus
	essence_per_sec = essence_flat * mult * travel_bonus
	rates_changed.emit(gold_per_sec, essence_per_sec)


## Accrue currency for the elapsed time.
func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	gold += gold_per_sec * delta
	essence += essence_per_sec * delta
	currency_changed.emit(gold, essence)


## Directly grant currency (used for offline earnings, rewards).
func grant_gold(amount: float) -> void:
	if amount <= 0.0:
		return
	gold += amount
	currency_changed.emit(gold, essence)


# --- Persistence -------------------------------------------------------

func to_dict() -> Dictionary:
	var upgrade_levels := {}
	for u in upgrades:
		upgrade_levels[u["id"]] = u["level"]
	var zone_states := {}
	for z in zones:
		zone_states[z["id"]] = z["unlocked"]
	return {
		"gold": gold,
		"essence": essence,
		"current_zone": current_zone,
		"upgrade_levels": upgrade_levels,
		"zone_states": zone_states,
	}


func from_dict(data: Dictionary) -> void:
	# Ensure definitions exist even if _ready() has not run (headless tests).
	if upgrades.is_empty():
		_define_upgrades()
	if zones.is_empty():
		_define_zones()

	gold = float(data.get("gold", 0.0))
	essence = float(data.get("essence", 0.0))
	current_zone = String(data.get("current_zone", "greenwood"))

	var upgrade_levels: Dictionary = data.get("upgrade_levels", {})
	for u in upgrades:
		if upgrade_levels.has(u["id"]):
			u["level"] = int(upgrade_levels[u["id"]])

	var zone_states: Dictionary = data.get("zone_states", {})
	for z in zones:
		if zone_states.has(z["id"]):
			z["unlocked"] = bool(zone_states[z["id"]])

	recompute_rates()
	currency_changed.emit(gold, essence)


## Reset to a fresh new-game economy.
func reset() -> void:
	gold = 0.0
	essence = 0.0
	current_zone = "greenwood"
	_define_upgrades()
	_define_zones()
	recompute_rates()
	currency_changed.emit(gold, essence)
