class_name Combatant
extends RefCounted
## Anything with HP in a fight: the player, enemies and (later) summons.
## Pure data plus queries; all mutation goes through CombatState so every
## change emits the right signals and triggers.

enum Side { PLAYER, ENEMY }

static var _next_id: int = 1

var id: int
var display_name: String
var side: Side
var max_hp: int
var hp: int
var block: int = 0
var is_dead: bool = false
## status id -> stacks. Dictionaries keep insertion order, which the status
## tray uses for display order.
var statuses: Dictionary = {}
## status id -> StatusEffectData
var status_data: Dictionary = {}
## Duration statuses applied during the enemy phase skip one round-end decay.
var skip_next_round_decay: Dictionary = {}


func _init(p_name: String, p_side: int, p_max_hp: int, p_hp: int = -1) -> void:
	id = _next_id
	_next_id += 1
	display_name = p_name
	side = p_side as Side
	max_hp = p_max_hp
	hp = p_max_hp if p_hp < 0 else mini(p_hp, p_max_hp)


func is_alive() -> bool:
	return not is_dead


func get_stacks(status_id: StringName) -> int:
	return statuses.get(status_id, 0)


func has_status(status_id: StringName) -> bool:
	return statuses.has(status_id)


func hp_ratio() -> float:
	return float(hp) / float(maxi(max_hp, 1))


## Sum of (per-stack property × stacks) over all statuses.
func stat_flat(property: StringName) -> float:
	var total := 0.0
	for status_id in statuses:
		total += float(status_data[status_id].get(property)) * statuses[status_id]
	return total


## Product of a multiplier property over all active statuses.
func stat_mult(property: StringName) -> float:
	var total := 1.0
	for status_id in statuses:
		if statuses[status_id] != 0:
			total *= float(status_data[status_id].get(property))
	return total


func retains_block() -> bool:
	for status_id in statuses:
		if status_data[status_id].retains_block:
			return true
	return false


func skips_turn() -> bool:
	for status_id in statuses:
		if status_data[status_id].skips_turn:
			return true
	return false


func _to_string() -> String:
	return "%s(%d/%d hp, %d block)" % [display_name, hp, max_hp, block]
