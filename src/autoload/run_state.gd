extends Node
## State of the run in progress (autoload: RunState).
##
## Owns everything that survives between screens during a run: deck, relics,
## potions, HP, gold, map position and RNG. It is serialised to user://run.json
## whenever the player arrives on the map (Slay the Spire style: quitting
## mid-combat resumes at the start of that node). Mid-combat saves are out of
## scope until Milestone 6.
##
## Co-op: one RunSeat per player holds their hero, HP, gold, deck, relics,
## potions and personal RNG (rewards, shops, events); the hp/gold/deck...
## fields below read the current seat, which is the local player's
## ([member home_seat]) except while another player's state is being updated.
## The map, act, floor and encounter history are shared, and everything the
## whole party sees (map layout, encounters, events, combat) draws from
## [member shared_rng]. In solo, shared_rng is the seat's own RNG, so solo
## runs are unchanged. Co-op runs are not saved.

const PATH := "user://run.json"
## Co-op runs save separately (every player's game keeps a copy), so a solo
## save and a co-op save never overwrite each other.
const COOP_PATH := "user://coop_run.json"
const VERSION := 1
const BASE_POTION_SLOTS := 3

var active: bool = false
var ascension: int = 0
## True for a co-op run (several seats, nothing saved).
var coop: bool = false
var seats: Array[RunSeat] = [RunSeat.new(0)]
var seat: RunSeat = seats[0]
## The local player's seat (co-op); 0 in solo.
var home_seat: int = 0
## Draws for things every player shares: map, encounters, events, combat.
var shared_rng: RngStreams

# The current seat's fields, under their solo names.
var class_id: StringName:
	get: return seat.class_id
	set(value): seat.class_id = value
## The current player's personal RNG (rewards, shop, event outcomes).
var rng: RngStreams:
	get: return seat.rng
	set(value): seat.rng = value
var max_hp: int:
	get: return seat.max_hp
	set(value): seat.max_hp = value
var hp: int:
	get: return seat.hp
	set(value): seat.hp = value
var gold: int:
	get: return seat.gold
	set(value): seat.gold = value
var deck: Array[CardInstance]:
	get: return seat.deck
	set(value): seat.deck = value
var relics: Array[RelicData]:
	get: return seat.relics
	set(value): seat.relics = value
## relic id -> counter value (for "every Nth" relics).
var relic_counters: Dictionary:
	get: return seat.relic_counters
	set(value): seat.relic_counters = value
## Fixed-size; empty slots are null.
var potions: Array:
	get: return seat.potions
	set(value): seat.potions = value
## Cards removed at shops (raises the removal price).
var removals: int:
	get: return seat.removals
	set(value): seat.removals = value
## Run-summary bookkeeping (the current player's).
var run_stats: Dictionary:
	get: return seat.run_stats
	set(value): seat.run_stats = value

var act: int = 1
## The act whose boss wins the run, fixed when the run starts.
var final_act: int = 3
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
## Where this copy of the game keeps its co-op save (tests run two copies on
## one machine with "--coop-save=user://other.json").
var coop_save_path := COOP_PATH


func start(class_data: CharacterClassData, ascension_level: int, run_seed: int) -> void:
	coop = false
	seats = [RunSeat.new(0)]
	home_seat = 0
	seat = seats[0]
	active = true
	ascension = ascension_level
	rng = RngStreams.new(run_seed)
	shared_rng = rng
	_start_seat(class_data)
	act = 1
	final_act = GameManager.final_act() if is_inside_tree() else GameManager.FINAL_ACT
	floor_number = 0
	map_data = {}
	visited_nodes = []
	current_node = ""
	monster_fights = 0
	seen_encounters = []
	seen_events = []


## A co-op run: one seat per entry of [param players] ({"name", "class_id"}),
## all built from [param run_seed] so every client creates the same run.
func start_coop(players: Array, ascension_level: int, run_seed: int, p_final_act: int, local_seat: int) -> void:
	coop = true
	seats = []
	active = true
	ascension = ascension_level
	shared_rng = RngStreams.new(run_seed)
	for i in players.size():
		var s := RunSeat.new(i)
		s.player_name = String(players[i].get("name", "Player %d" % (i + 1)))
		s.rng = RngStreams.new(hash("%d:seat:%d" % [run_seed, i]))
		seats.append(s)
		seat = s
		_start_seat(ContentDB.get_character_class(StringName(players[i].class_id)))
	home_seat = local_seat
	seat = seats[home_seat]
	act = 1
	final_act = p_final_act
	floor_number = 0
	map_data = {}
	visited_nodes = []
	current_node = ""
	monster_fights = 0
	seen_encounters = []
	seen_events = []


## Fills the current seat with [param class_data]'s starting hero.
func _start_seat(class_data: CharacterClassData) -> void:
	class_id = class_data.id
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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--coop-save="):
			coop_save_path = arg.trim_prefix("--coop-save=")
	EventBus.card_played.connect(func(_card, _targets): _stat("cards_played", 1))
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.combatant_died.connect(func(c):
		if c is EnemyCombatant and not c is SummonCombatant:
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
		if info.target.seat_index == home_seat:
			_stat("damage_taken", info.hp_lost)
	elif info.source is PlayerCombatant and info.source.seat_index == home_seat:
		_stat("damage_dealt", info.hp_lost)
		run_stats["biggest_hit"] = maxi(int(run_stats.get("biggest_hit", 0)), info.hp_lost)


## Floors climbed over the whole run (each act has FLOORS + the boss).
func total_floor() -> int:
	return (mini(act, 4) - 1) * (MapGenerator.FLOORS + 1) + floor_number


func current_map_node() -> Dictionary:
	if map_data.is_empty() or current_node == "":
		return {}
	return map_data.nodes.get(current_node, {})


func get_class_data() -> CharacterClassData:
	return ContentDB.get_character_class(class_id)


# --- Seats (co-op) ---------------------------------------------------------------

## Runs [param action] with [param index]'s seat as the current one (another
## player's rewards, combat results...), then switches back.
func with_seat(index: int, action: Callable) -> void:
	var previous := seat
	seat = seats[index]
	action.call()
	seat = previous


## True while the current seat is the local player's (only they drive the UI).
func is_home() -> bool:
	return seat.index == home_seat


func home() -> RunSeat:
	return seats[home_seat]


# --- HP & gold ----------------------------------------------------------------

func set_hp(value: int) -> void:
	var old := hp
	hp = clampi(value, 0, max_hp)
	if hp != old and is_home():
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
	if is_home():
		EventBus.gold_changed.emit(old, gold)


func can_afford(cost: int) -> bool:
	return gold >= cost


# --- Deck -----------------------------------------------------------------------

func add_card(card: CardData, upgraded: bool = false) -> CardInstance:
	var inst := CardInstance.new(card, upgraded)
	deck.append(inst)
	if is_home():
		EventBus.card_added_to_deck.emit(inst)
	return inst


func remove_card(inst: CardInstance) -> void:
	if deck.has(inst):
		deck.erase(inst)
		if is_home():
			EventBus.card_removed_from_deck.emit(inst)


func upgrade_card(inst: CardInstance) -> void:
	if inst.can_upgrade():
		inst.upgrade()
		if is_home():
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
	if is_home():
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
			if is_home():
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
		"potions": potion_ids, "act": act, "final_act": final_act, "floor": floor_number,
		"map": map_data, "visited": visited_nodes, "stats": run_stats,
		"current_node": current_node, "monster_fights": monster_fights,
		"seen_encounters": seen_encounters, "seen_events": seen_events, "removals": removals,
	}


func from_dict(data: Dictionary) -> void:
	coop = false
	seats = [RunSeat.new(0)]
	home_seat = 0
	seat = seats[0]
	class_id = StringName(data.get("class_id", ""))
	ascension = int(data.get("ascension", 0))
	rng = RngStreams.from_dict(data.get("rng", {}))
	shared_rng = rng
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
	final_act = int(data.get("final_act", GameManager.FINAL_ACT))
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


# --- Co-op save -------------------------------------------------------------------

## The whole shared run: every seat plus the map, act and shared RNG.
func to_coop_dict() -> Dictionary:
	var seat_dicts: Array = []
	for s in seats:
		seat_dicts.append(s.to_dict())
	return {
		"coop": true, "ascension": ascension, "shared_rng": shared_rng.to_dict(), "seats": seat_dicts,
		"act": act, "final_act": final_act, "floor": floor_number, "map": map_data, "visited": visited_nodes,
		"current_node": current_node, "monster_fights": monster_fights,
		"seen_encounters": seen_encounters, "seen_events": seen_events,
	}


## Loads a co-op run (from a save, via the host) with [param local_seat] as this player.
func from_coop_dict(data: Dictionary, local_seat: int) -> void:
	coop = true
	active = true
	ascension = int(data.get("ascension", 0))
	shared_rng = RngStreams.from_dict(data.get("shared_rng", {}))
	seats = []
	var seat_dicts: Array = data.get("seats", [])
	for i in seat_dicts.size():
		var s := RunSeat.new(i)
		s.from_dict(seat_dicts[i])
		seats.append(s)
	home_seat = clampi(local_seat, 0, seats.size() - 1)
	seat = seats[home_seat]
	act = int(data.get("act", 1))
	final_act = int(data.get("final_act", GameManager.FINAL_ACT))
	floor_number = int(data.get("floor", 0))
	map_data = data.get("map", {})
	visited_nodes = data.get("visited", [])
	current_node = String(data.get("current_node", ""))
	monster_fights = int(data.get("monster_fights", 0))
	seen_encounters = data.get("seen_encounters", [])
	seen_events = data.get("seen_events", [])


## Every player's game saves the co-op run whenever the party is on the map.
func save_coop() -> void:
	if active and coop:
		SaveIO.write_json(coop_save_path, to_coop_dict(), VERSION)


func has_coop_save() -> bool:
	return FileAccess.file_exists(coop_save_path)


func load_coop_save() -> Dictionary:
	var data := SaveIO.read_json(coop_save_path)
	data.erase(SaveIO.VERSION_KEY)
	return data if data.get("coop", false) and not data.get("seats", []).is_empty() else {}


func clear_coop_save() -> void:
	SaveIO.delete(coop_save_path)


## "Ana (Pyre Warden), Bo (Moonblade) · Act 1, floor 3" for a co-op save.
static func describe_coop_save(data: Dictionary) -> String:
	var names: PackedStringArray = []
	for s in data.get("seats", []):
		var cls := ContentDB.get_character_class(StringName(s.get("class_id", "")))
		names.append("%s (%s)" % [s.get("name", "?"), cls.display_name if cls else "?"])
	return "%s · Act %d, floor %d" % [", ".join(names), int(data.get("act", 1)), int(data.get("floor", 0))]


func save_run() -> void:
	if active and not coop:
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
	if not coop:
		SaveIO.delete(PATH)
	coop = false
