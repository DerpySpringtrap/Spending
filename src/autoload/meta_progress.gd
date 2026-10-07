extends Node
## Permanent, cross-run progression (autoload: MetaProgress).
##
## Saved to user://meta.json, completely separate from the current-run save
## (user://run.json). Losing or abandoning a run never touches this file;
## a corrupt run save can be deleted without costing the player their unlocks.

const PATH := "user://meta.json"
const VERSION := 1

## Total class XP needed for each level (index 0 = level 1).
const LEVEL_XP: Array[int] = [0, 60, 160, 300]
## What each level unlocks, for the summary and class select.
const LEVEL_REWARDS := {
	2: "3 new cards join the reward pool",
	3: "Class relics can now drop",
	4: "3 more new cards join the reward pool",
}
## Classes unlocked by finishing any run.
const FIRST_RUN_UNLOCKS: Array[StringName] = [&"moonblade"]
## Classes unlocked by reaching (fighting) the Act 2 boss.
const ACT2_BOSS_UNLOCKS: Array[StringName] = [&"hollow_scribe"]
## Classes unlocked by defeating the Act 2 boss.
const ACT2_WIN_UNLOCKS: Array[StringName] = [&"rootmother"]

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
## Debug / play-testing: every class, card and relic is available (F8).
var unlock_all := false
## Act 4 (the Umbral Core) appears after the player's first Act 3 victory.
var act4_won_once := false
var act4_unlocked: bool:
	get:
		return act4_won_once or unlock_all


func _ready() -> void:
	load_meta()


func is_class_unlocked(class_id: StringName) -> bool:
	if unlock_all or unlocked_classes.has(class_id):
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
	if unlock_all:
		return GameManager.MAX_ASCENSION
	return int(max_ascension.get(class_id, 0))


func get_class_xp(class_id: StringName) -> int:
	return int(class_xp.get(class_id, 0))


static func level_for_xp(xp: int) -> int:
	var level := 1
	for i in LEVEL_XP.size():
		if xp >= LEVEL_XP[i]:
			level = i + 1
	return level


func get_class_level(class_id: StringName) -> int:
	return level_for_xp(get_class_xp(class_id))


static func max_level() -> int:
	return LEVEL_XP.size()


## [from, to] XP bounds of the current level ([to] = -1 at max level).
static func level_bounds(xp: int) -> Vector2i:
	var level := level_for_xp(xp)
	var next := LEVEL_XP[level] if level < LEVEL_XP.size() else -1
	return Vector2i(LEVEL_XP[level - 1], next)


## True if content needing [param level] is available for [param pool_id]
## (a class id; neutral pools are always unlocked).
func is_level_unlocked(pool_id: StringName, level: int) -> bool:
	if level <= 1 or unlock_all:
		return true
	if ContentDB.get_character_class(pool_id) == null:
		return true
	return get_class_level(pool_id) >= level


## Called by GameManager when a run ends. Returns what happened for the
## summary: {"xp", "old_xp", "new_xp", "old_level", "new_level", "unlocks": [String]}.
func record_run(class_id: StringName, victory: bool, floor_reached: int, ascension: int, xp: int,
		reached_act2_boss: bool = false, beat_act2_boss: bool = false, beat_act3_boss: bool = false) -> Dictionary:
	stats["runs_won"] += 1 if victory else 0
	stats["highest_floor"] = maxi(stats["highest_floor"], floor_reached)
	var old_xp := get_class_xp(class_id)
	var old_level := level_for_xp(old_xp)
	class_xp[class_id] = old_xp + xp
	var new_level := get_class_level(class_id)
	var unlocks: Array[String] = []
	var cls_name := String(class_id).capitalize()
	var cls: CharacterClassData = ContentDB.get_character_class(class_id)
	if cls:
		cls_name = cls.display_name
	for level in range(old_level + 1, new_level + 1):
		unlocks.append("%s level %d: %s" % [cls_name, level, LEVEL_REWARDS.get(level, "")])
	var class_unlocks: Array[StringName] = FIRST_RUN_UNLOCKS.duplicate()
	if reached_act2_boss:
		class_unlocks.append_array(ACT2_BOSS_UNLOCKS)
	if beat_act2_boss:
		class_unlocks.append_array(ACT2_WIN_UNLOCKS)
	for unlock_id in class_unlocks:
		if not unlocked_classes.has(unlock_id) and not is_class_unlocked(unlock_id):
			unlock(&"class", unlock_id)
			var data: CharacterClassData = ContentDB.get_character_class(unlock_id)
			unlocks.append("New class unlocked: %s" % (data.display_name if data else String(unlock_id)))
	if beat_act3_boss and not act4_won_once:
		act4_won_once = true
		unlocks.append("Act 4 unlocked: The Umbral Core awaits beyond the Orrery")
	if victory and ascension >= int(max_ascension.get(class_id, 0)) and ascension < GameManager.MAX_ASCENSION:
		max_ascension[class_id] = ascension + 1
		unlocks.append("Ascension %d unlocked for %s" % [ascension + 1, cls_name])
	save_meta()
	return {"xp": xp, "old_xp": old_xp, "new_xp": old_xp + xp, "old_level": old_level, "new_level": new_level,
		"unlocks": unlocks}


func to_dict() -> Dictionary:
	return {
		"unlocked_classes": _to_strings(unlocked_classes),
		"unlocked_cards": _to_strings(unlocked_cards),
		"unlocked_relics": _to_strings(unlocked_relics),
		"max_ascension": max_ascension,
		"class_xp": class_xp,
		"stats": stats,
		"seen_enemies": _to_strings(seen_enemies),
		"unlock_all": unlock_all,
		"act4_unlocked": act4_won_once,
	}


func from_dict(data: Dictionary) -> void:
	unlocked_classes = _to_string_names(data.get("unlocked_classes", []))
	unlocked_cards = _to_string_names(data.get("unlocked_cards", []))
	unlocked_relics = _to_string_names(data.get("unlocked_relics", []))
	seen_enemies = _to_string_names(data.get("seen_enemies", []))
	unlock_all = bool(data.get("unlock_all", false))
	act4_won_once = bool(data.get("act4_unlocked", false))
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
