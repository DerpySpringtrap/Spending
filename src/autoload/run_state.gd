extends Node
## State of the run in progress (autoload: RunState).
##
## Owns everything that survives between screens during a run: deck, relics,
## potions, HP, gold, map position and RNG. It is serialised to user://run.json
## whenever the player arrives on the map (Slay the Spire style: quitting
## mid-combat resumes at the start of that node). Mid-combat saves are out of
## scope until Milestone 6.

const PATH := "user://run.json"
const VERSION := 1
const BASE_POTION_SLOTS := 3

var active: bool = false
var class_id: StringName = &""
var ascension: int = 0
var rng: RngStreams

var max_hp: int = 0
var hp: int = 0
var gold: int = 0
var deck: Array[CardInstance] = []
var relics: Array[RelicData] = []
## relic id -> counter value (for "every Nth" relics).
var relic_counters: Dictionary = {}
## Fixed-size; empty slots are null.
var potions: Array = []

var act: int = 1
var floor_number: int = 0
## Map is generated per act from the "map" stream; we persist the generated
## layout plus the visited path. Shape filled in by MapGenerator (Milestone 3).
var map_data: Dictionary = {}
var visited_nodes: Array = []
## Map node the player is on ("" = before floor 1).
var current_node: String = ""
var monster_fights: int = 0
var seen_encounters: Array = []
var seen_events: Array = []
## Cards removed at shops (raises the removal price).
var removals: int = 0

## Run-summary bookkeeping.
var run_stats: Dictionary = {}


func start(class_data: CharacterClassData, ascension_level: int, run_seed: int) -> void:
	active = true
	class_id = class_data.id
	ascension = ascension_level
	rng = RngStreams.new(run_seed)
	max_hp = class_data.max_hp
	hp = max_hp
	gold = class_data.starting_gold
	deck.clear()
	for card in class_data.starting_deck:
		deck.append(CardInstance.new(card))
	relics.clear()
	relic_counters.clear()
	if class_data.starting_relic:
		add_relic(class_data.starting_relic)
	potions.clear()
	potions.resize(get_potion_slot_count())
	act = 1
	floor_number = 0
	map_data = {}
	visited_nodes = []
	current_node = ""
	monster_fights = 0
	seen_encounters = []
	seen_events = []
	removals = 0
	run_stats = {"damage_dealt": 0, "damage_taken": 0, "cards_played": 0, "gold_earned": 0, "enemies_killed": 0,
		"elites_killed": 0, "biggest_hit": 0}
	if ascension >= AscensionRules.MAX_HP_LEVEL:
		max_hp -= AscensionRules.MAX_HP_PENALTY
		hp = mini(hp, max_hp)
	if ascension >= AscensionRules.START_DAMAGED_LEVEL:
		hp = roundi(max_hp * 0.9)
	if ascension >= AscensionRules.CURSE_LEVEL:
		var curse := ContentDB.get_card(&"weight_of_dusk")
		if curse:
			deck.append(CardInstance.new(curse))


func _ready() -> void:
	EventBus.card_played.connect(func(_card, _targets): _stat("cards_played", 1))
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.combatant_died.connect(func(c):
		if c is EnemyCombatant:
			_stat("enemies_killed", 1)
			if c.data.tier == EnemyData.Tier.ELITE:
				_stat("elites_killed", 1))


func _stat(key: String, amount: int) -> void:
	if active:
		run_stats[key] = int(run_stats.get(key, 0)) + amount


func _on_damage_dealt(info: DamageInfo) -> void:
	if not active or info.hp_lost <= 0:
		return
	if info.target is PlayerCombatant:
		_stat("damage_taken", info.hp_lost)
	elif info.source is PlayerCombatant:
		_stat("damage_dealt", info.hp_lost)
		run_stats["biggest_hit"] = maxi(int(run_stats.get("biggest_hit", 0)), info.hp_lost)


## Floors climbed over the whole run (each act has FLOORS + the boss).
func total_floor() -> int:
	return (act - 1) * (MapGenerator.FLOORS + 1) + floor_number


func current_map_node() -> Dictionary:
	if map_data.is_empty() or current_node == "":
		return {}
	return map_data.nodes.get(current_node, {})


func get_class_data() -> CharacterClassData:
	return ContentDB.get_character_class(class_id)


# --- HP & gold ----------------------------------------------------------------

func set_hp(value: int) -> void:
	var old := hp
	hp = clampi(value, 0, max_hp)
	if hp != old:
		EventBus.run_hp_changed.emit(old, hp, max_hp)


func heal(amount: int) -> void:
	set_hp(hp + amount)


func change_max_hp(delta: int) -> void:
	max_hp = maxi(1, max_hp + delta)
	set_hp(hp + maxi(delta, 0))


func add_gold(amount: int) -> void:
	var old := gold
	gold = maxi(0, gold + amount)
	if amount > 0:
		run_stats["gold_earned"] = run_stats.get("gold_earned", 0) + amount
	EventBus.gold_changed.emit(old, gold)


func can_afford(cost: int) -> bool:
	return gold >= cost


# --- Deck -----------------------------------------------------------------------

func add_card(card: CardData, upgraded: bool = false) -> CardInstance:
	var inst := CardInstance.new(card, upgraded)
	deck.append(inst)
	EventBus.card_added_to_deck.emit(inst)
	return inst


func remove_card(inst: CardInstance) -> void:
	if deck.has(inst):
		deck.erase(inst)
		EventBus.card_removed_from_deck.emit(inst)


func upgrade_card(inst: CardInstance) -> void:
	if inst.can_upgrade():
		inst.upgrade()
		EventBus.card_upgraded.emit(inst)


# --- Relics & potions -----------------------------------------------------------

func add_relic(relic: RelicData) -> void:
	if has_relic(relic.id):
		return
	relics.append(relic)
	if relic.max_hp_bonus != 0:
		change_max_hp(relic.max_hp_bonus)
	if relic.potion_slot_bonus != 0:
		potions.resize(get_potion_slot_count())
	EventBus.relic_obtained.emit(relic)


func has_relic(id: StringName) -> bool:
	for relic in relics:
		if relic.id == id:
			return true
	return false


func get_potion_slot_count() -> int:
	var slots := BASE_POTION_SLOTS
	if ascension >= 11:
		slots -= 1
	for relic in relics:
		slots += relic.potion_slot_bonus
	return maxi(slots, 0)


## Returns the slot index used, or -1 if all slots are full.
func add_potion(potion: PotionData) -> int:
	for i in potions.size():
		if potions[i] == null:
			potions[i] = potion
			EventBus.potion_obtained.emit(potion, i)
			return i
	return -1


func remove_potion(slot: int) -> PotionData:
	var potion: PotionData = potions[slot]
	potions[slot] = null
	return potion


# --- Persistence ----------------------------------------------------------------

func to_dict() -> Dictionary:
	var potion_ids: Array = []
	for potion in potions:
		potion_ids.append(String(potion.id) if potion else "")
	var relic_ids: Array[String] = []
	for relic in relics:
		relic_ids.append(String(relic.id))
	var deck_entries: Array[Dictionary] = []
	for card in deck:
		deck_entries.append(card.to_dict())
	return {
		"class_id": String(class_id), "ascension": ascension, "rng": rng.to_dict(),
		"max_hp": max_hp, "hp": hp, "gold": gold,
		"deck": deck_entries, "relics": relic_ids, "relic_counters": relic_counters,
		"potions": potion_ids, "act": act, "floor": floor_number,
		"map": map_data, "visited": visited_nodes, "stats": run_stats,
		"current_node": current_node, "monster_fights": monster_fights,
		"seen_encounters": seen_encounters, "seen_events": seen_events, "removals": removals,
	}


func from_dict(data: Dictionary) -> void:
	class_id = StringName(data.get("class_id", ""))
	ascension = int(data.get("ascension", 0))
	rng = RngStreams.from_dict(data.get("rng", {}))
	max_hp = int(data.get("max_hp", 1))
	hp = int(data.get("hp", 1))
	gold = int(data.get("gold", 0))
	deck.clear()
	for entry in data.get("deck", []):
		var inst := CardInstance.from_dict(entry, ContentDB.get_card)
		if inst:
			deck.append(inst)
	relics.clear()
	for id in data.get("relics", []):
		var relic := ContentDB.get_relic(StringName(id))
		if relic:
			relics.append(relic)
	relic_counters = data.get("relic_counters", {})
	potions.clear()
	for id in data.get("potions", []):
		potions.append(ContentDB.get_potion(StringName(id)) if id != "" else null)
	act = int(data.get("act", 1))
	floor_number = int(data.get("floor", 0))
	map_data = data.get("map", {})
	visited_nodes = data.get("visited", [])
	run_stats = data.get("stats", {})
	current_node = String(data.get("current_node", ""))
	monster_fights = int(data.get("monster_fights", 0))
	seen_encounters = data.get("seen_encounters", [])
	seen_events = data.get("seen_events", [])
	removals = int(data.get("removals", 0))
	active = true


func save_run() -> void:
	if active:
		SaveIO.write_json(PATH, to_dict(), VERSION)


func has_saved_run() -> bool:
	return FileAccess.file_exists(PATH)


func load_run() -> bool:
	var data := SaveIO.read_json(PATH)
	if data.is_empty():
		return false
	from_dict(data)
	return ContentDB.get_character_class(class_id) != null


func clear() -> void:
	active = false
	SaveIO.delete(PATH)
