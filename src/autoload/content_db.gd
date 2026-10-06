extends Node
## Content registry (autoload: ContentDB).
##
## Scans res://content/ at startup, loads every .tres and indexes it by type and
## id. Designers add content by dropping a resource into the right folder; no
## code or manual registration needed. Duplicate ids are reported as errors.

const CONTENT_ROOT := "res://content"

var cards: Dictionary = {}       # StringName -> CardData
var statuses: Dictionary = {}    # StringName -> StatusEffectData
var relics: Dictionary = {}      # StringName -> RelicData
var potions: Dictionary = {}     # StringName -> PotionData
var enemies: Dictionary = {}     # StringName -> EnemyData
var encounters: Dictionary = {}  # StringName -> EncounterData
var classes: Dictionary = {}     # StringName -> CharacterClassData

var _id_owner: Dictionary = {}   # "<kind>:<id>" -> resource path, for duplicate checks


func _ready() -> void:
	reload()


func reload() -> void:
	for registry in [cards, statuses, relics, potions, enemies, encounters, classes]:
		registry.clear()
	_id_owner.clear()
	_scan(CONTENT_ROOT)
	print("ContentDB: %d cards, %d statuses, %d relics, %d potions, %d enemies, %d encounters, %d classes" % [
		cards.size(), statuses.size(), relics.size(), potions.size(),
		enemies.size(), encounters.size(), classes.size(),
	])


func _scan(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan(full)
		else:
			# Exported builds list "foo.tres.remap"; load() resolves the remap.
			var res_path := full.trim_suffix(".remap")
			if res_path.ends_with(".tres") or res_path.ends_with(".res"):
				_register(load(res_path), res_path)
		entry = dir.get_next()
	dir.list_dir_end()


func _register(res: Resource, path: String) -> void:
	if res is CardData:
		_add(cards, "card", res.id, res, path)
	elif res is StatusEffectData:
		_add(statuses, "status", res.id, res, path)
	elif res is RelicData:
		_add(relics, "relic", res.id, res, path)
	elif res is PotionData:
		_add(potions, "potion", res.id, res, path)
	elif res is EnemyData:
		_add(enemies, "enemy", res.id, res, path)
	elif res is EncounterData:
		_add(encounters, "encounter", res.id, res, path)
	elif res is CharacterClassData:
		_add(classes, "class", res.id, res, path)
	# Other resources (sub-resources saved to disk, themes...) are ignored.


func _add(registry: Dictionary, kind: String, id: StringName, res: Resource, path: String) -> void:
	if id == &"":
		push_error("ContentDB: %s has an empty id" % path)
		return
	var key := "%s:%s" % [kind, id]
	if _id_owner.has(key):
		push_error("ContentDB: duplicate %s id '%s' in %s (already used by %s)" % [kind, id, path, _id_owner[key]])
		return
	_id_owner[key] = path
	registry[id] = res


# --- Lookups ------------------------------------------------------------------

func get_card(id: StringName) -> CardData:
	return cards.get(id)


func get_status(id: StringName) -> StatusEffectData:
	return statuses.get(id)


func get_relic(id: StringName) -> RelicData:
	return relics.get(id)


func get_potion(id: StringName) -> PotionData:
	return potions.get(id)


func get_enemy(id: StringName) -> EnemyData:
	return enemies.get(id)


func get_encounter(id: StringName) -> EncounterData:
	return encounters.get(id)


func get_character_class(id: StringName) -> CharacterClassData:
	return classes.get(id)


## Cards that can appear as rewards for a class (excludes starters/special).
func get_reward_pool(pool_id: StringName, rarity: CardData.Rarity) -> Array[CardData]:
	var result: Array[CardData] = []
	for card: CardData in cards.values():
		if card.card_pool == pool_id and card.rarity == rarity:
			result.append(card)
	return result


func get_encounters(act: int, pool: EncounterData.Pool) -> Array[EncounterData]:
	var result: Array[EncounterData] = []
	for enc: EncounterData in encounters.values():
		if enc.act == act and enc.pool == pool:
			result.append(enc)
	return result


func get_relics_by_rarity(rarity: RelicData.Rarity, class_id: StringName = &"") -> Array[RelicData]:
	var result: Array[RelicData] = []
	for relic: RelicData in relics.values():
		if relic.rarity == rarity and (relic.class_restriction == &"" or relic.class_restriction == class_id):
			result.append(relic)
	return result
