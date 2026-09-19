extends Node
## StoryGenerator: builds a fresh randomized (but coherent) fantasy plot from a
## seed. The same seed always yields the same story, so we persist the seed and
## regenerate deterministically across reloads. Each chapter unlock reveals the
## next narrative beat.

var seed_value: int = 0

# Generated story elements (derived from the seed).
var hero_name: String = ""
var hero_origin: String = ""
var artifact: String = ""
var quest_verb: String = ""
var antagonist: String = ""
var antagonist_title: String = ""

# --- Curated word banks -------------------------------------------------

const HERO_FIRST := [
	"Aldric", "Bryndis", "Caelum", "Dahlia", "Eirik",
	"Faye", "Gorran", "Halcyon", "Isolde", "Kael",
	"Lyra", "Marek", "Nyssa", "Orin", "Sable",
]
const HERO_EPITHET := [
	"the Unbroken", "the Wandering", "the Emberborn", "the Quiet",
	"of the Green Vale", "Stormhand", "the Last Lantern", "Dawnseeker",
]
const ORIGINS := [
	"a forgotten village at the edge of the map",
	"a crumbling monastery in the highlands",
	"a caravan lost between two kingdoms",
	"the ashes of a burned homestead",
	"a hidden order of star-readers",
]
const ARTIFACTS := [
	"the Sunder Crown", "the Everflame Shard", "the Whispering Compass",
	"the Heartstone of Aeon", "the Tidebound Grimoire", "the Hollow Key",
	"the Aurora Blade", "the Chalice of Endless Dawn",
]
const QUEST_VERBS := [
	"reclaim", "shatter", "awaken", "return", "seal away", "restore",
]
const ANTAGONISTS := [
	"Vorren", "Maligar", "the Ashen Queen", "Threxis", "Umbra Vael",
	"the Gravewright", "Sythra", "the Pale Regent",
]
const ANTAGONIST_TITLES := [
	"Devourer of Kingdoms", "the Broken Prophet", "Warden of the Void",
	"who unmade the stars", "the Endless Hunger", "keeper of a thousand chains",
]

# Per-chapter beat templates. {hero}, {artifact}, {foe}, {zone} are substituted.
const CHAPTER_BEATS := [
	[
		"In the Greenwood Vale, {hero} first hears the legend of {artifact}.",
		"The Greenwood Vale still remembers {hero}; here the long road begins.",
		"{hero} sets out from the Greenwood Vale, the weight of prophecy heavy.",
	],
	[
		"Climbing the Emberpeak Foothills, {hero} learns that {foe} seeks {artifact} too.",
		"Smoke over Emberpeak marks where {foe}'s hunters first cross {hero}'s path.",
		"In Emberpeak, an old scout reveals the first shard of {artifact}.",
	],
	[
		"Deep in the Sunken Crypt, {hero} uncovers half of {artifact} amid the drowned dead.",
		"The Sunken Crypt tests {hero}: its ghosts once served {foe}.",
		"Beneath still water, {hero} claims a fragment and a warning about {foe}.",
	],
	[
		"Across the Frostspire Reaches, {hero} races {foe} for the final piece of {artifact}.",
		"Frostspire's blizzards nearly bury {hero}, but {foe}'s trail is close now.",
		"On the Frostspire, {hero} and {foe} clash for the first time and both survive.",
	],
	[
		"At the Voidgate Citadel, {hero} confronts {foe} to decide the fate of {artifact}.",
		"The Voidgate opens; {hero} must {quest} {artifact} before {foe} does.",
		"In the Citadel's heart, {hero} makes the final stand against {foe}.",
	],
]


func _ready() -> void:
	if seed_value == 0:
		generate(_random_seed())


func _random_seed() -> int:
	# Non-deterministic seed for a truly fresh plot on new game.
	return int(Time.get_unix_time_from_system()) ^ (randi() << 8)


## Generate the plot from a seed. Deterministic for a given seed.
func generate(new_seed: int) -> void:
	seed_value = new_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = new_seed

	hero_name = _pick(rng, HERO_FIRST) + " " + _pick(rng, HERO_EPITHET)
	hero_origin = _pick(rng, ORIGINS)
	artifact = _pick(rng, ARTIFACTS)
	quest_verb = _pick(rng, QUEST_VERBS)
	antagonist = _pick(rng, ANTAGONISTS)
	antagonist_title = _pick(rng, ANTAGONIST_TITLES)


func _pick(rng: RandomNumberGenerator, bank: Array) -> String:
	return bank[rng.randi_range(0, bank.size() - 1)]


func _substitute(text: String) -> String:
	return text.replace("{hero}", hero_name) \
		.replace("{artifact}", artifact) \
		.replace("{foe}", antagonist) \
		.replace("{quest}", quest_verb)


## Intro shown when a new game starts.
func get_intro() -> String:
	return "%s rose from %s, sworn to %s %s before %s, %s, could claim it." % [
		hero_name, hero_origin, quest_verb, artifact, antagonist, antagonist_title,
	]


## Narrative beat for a given chapter index (0-based). Deterministic per seed.
func get_chapter_text(index: int) -> String:
	if index < 0 or index >= CHAPTER_BEATS.size():
		return ""
	var variants: Array = CHAPTER_BEATS[index]
	# Pick a variant deterministically from the seed + chapter so reloads match.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + index * 1000
	var choice: int = rng.randi_range(0, variants.size() - 1)
	return _substitute(variants[choice])


func chapter_count() -> int:
	return CHAPTER_BEATS.size()


# --- Persistence -------------------------------------------------------

func to_dict() -> Dictionary:
	return {"seed": seed_value}


func from_dict(data: Dictionary) -> void:
	var s := int(data.get("seed", 0))
	if s == 0:
		s = _random_seed()
	generate(s)


func new_random_story() -> void:
	generate(_random_seed())
