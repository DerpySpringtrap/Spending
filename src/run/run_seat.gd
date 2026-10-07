class_name RunSeat
extends RefCounted
## One player's part of a run: hero, HP, gold, deck, relics, potions and their
## personal RNG (rewards, shops, events). Solo runs have one seat; co-op runs
## have one per player. RunState's hp/gold/deck... fields read the current seat.

var index: int = 0
## Display name (co-op lobby); empty in solo.
var player_name: String = ""
var class_id: StringName = &""
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
## Cards removed at shops (raises the removal price).
var removals: int = 0
## Run-summary bookkeeping.
var run_stats: Dictionary = {}


func _init(p_index: int = 0) -> void:
	index = p_index


## Everything the other players need to mirror this seat (co-op sync).
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
		"name": player_name, "class_id": String(class_id), "rng": rng.to_dict(),
		"max_hp": max_hp, "hp": hp, "gold": gold,
		"deck": deck_entries, "relics": relic_ids, "relic_counters": relic_counters.duplicate(),
		"potions": potion_ids, "removals": removals, "stats": run_stats.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	player_name = String(data.get("name", player_name))
	class_id = StringName(data.get("class_id", ""))
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
	removals = int(data.get("removals", 0))
	run_stats = data.get("stats", {})
