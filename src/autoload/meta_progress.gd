extends Node
## Permanent, cross-run progression (autoload: MetaProgress).
##
## Saved to user://meta.json, completely separate from the current-run save
## (user://run.json). Losing or abandoning a run never touches this file;
## a corrupt run save can be deleted without costing the player their unlocks.

const PATH := "user://meta.json"
const VERSION := 1

var unlocked_classes: Array[StringName] = []
var unlocked_cards: Array[StringName] = []
var unlocked_relics: Array[StringName] = []
## class_id -> highest ascension unlocked for that class.
var max_ascension: Dictionary = {}
## class_id -> class XP, which feeds the per-class unlock tracks.
var class_xp: Dictionary = {}
## Lifetime stats for the stats screen and achievements.
var stats: Dictionary = {
	"runs_started": 0, "runs_won": 0, "enemies_killed": 0,
	"elites_killed": 0, "bosses_killed": 0, "highest_floor": 0,
}
## Enemy ids the player has met (bestiary / first-encounter gimmick popups).
var seen_enemies: Array[StringName] = []


func _ready() -> void:
	load_meta()


func is_class_unlocked(class_id: StringName) -> bool:
	if unlocked_classes.has(class_id):
		return true
	var data: CharacterClassData = ContentDB.get_character_class(class_id)
	return data != null and data.unlocked_by_default


func unlock(kind: StringName, id: StringName) -> void:
	var list: Array[StringName]
	match kind:
		&"class": list = unlocked_classes
		&"card": list = unlocked_cards
		&"relic": list = unlocked_relics
		_:
			push_error("MetaProgress: unknown unlock kind %s" % kind)
			return
	if not list.has(id):
		list.append(id)
		EventBus.unlock_earned.emit(kind, id)


func get_max_ascension(class_id: StringName) -> int:
	return int(max_ascension.get(class_id, 0))


## Called by GameManager when a run ends. Returns the XP earned for the summary.
func record_run(class_id: StringName, victory: bool, floor_reached: int, ascension: int, xp: int) -> int:
	stats["runs_won"] += 1 if victory else 0
	stats["highest_floor"] = maxi(stats["highest_floor"], floor_reached)
	class_xp[class_id] = int(class_xp.get(class_id, 0)) + xp
	if victory and ascension >= get_max_ascension(class_id):
		max_ascension[class_id] = mini(ascension + 1, GameManager.MAX_ASCENSION)
	save_meta()
	return xp


func to_dict() -> Dictionary:
	return {
		"unlocked_classes": _to_strings(unlocked_classes),
		"unlocked_cards": _to_strings(unlocked_cards),
		"unlocked_relics": _to_strings(unlocked_relics),
		"max_ascension": max_ascension,
		"class_xp": class_xp,
		"stats": stats,
		"seen_enemies": _to_strings(seen_enemies),
	}


func from_dict(data: Dictionary) -> void:
	unlocked_classes = _to_string_names(data.get("unlocked_classes", []))
	unlocked_cards = _to_string_names(data.get("unlocked_cards", []))
	unlocked_relics = _to_string_names(data.get("unlocked_relics", []))
	seen_enemies = _to_string_names(data.get("seen_enemies", []))
	max_ascension.clear()
	for key in data.get("max_ascension", {}):
		max_ascension[StringName(key)] = int(data["max_ascension"][key])
	class_xp.clear()
	for key in data.get("class_xp", {}):
		class_xp[StringName(key)] = int(data["class_xp"][key])
	var saved_stats: Dictionary = data.get("stats", {})
	for key in saved_stats:
		stats[key] = int(saved_stats[key])


func save_meta() -> void:
	SaveIO.write_json(PATH, to_dict(), VERSION)


func load_meta() -> void:
	var data := SaveIO.read_json(PATH)
	if not data.is_empty():
		# Future format changes: migrate here based on SaveIO.get_version(data).
		from_dict(data)


func reset_all_progress() -> void:
	from_dict({})
	stats = {
		"runs_started": 0, "runs_won": 0, "enemies_killed": 0,
		"elites_killed": 0, "bosses_killed": 0, "highest_floor": 0,
	}
	SaveIO.delete(PATH)


static func _to_strings(list: Array[StringName]) -> Array[String]:
	var out: Array[String] = []
	for item in list:
		out.append(String(item))
	return out


static func _to_string_names(list: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for item in list:
		out.append(StringName(item))
	return out
