class_name CardInstance
extends RefCounted
## A specific copy of a card in the player's deck (or created during combat).
##
## The deck in RunState holds the permanent copies. At combat start each one is
## cloned with [method clone_for_combat] so combat-only changes ("costs 0 this
## combat") never leak back into the deck.

static var _next_uid: int = 1

var data: CardData
var upgraded: bool = false
## Unique for the session, so UI nodes and animations can track a card as it
## moves between piles.
var uid: int
## Combat-only state.
var cost_override_this_turn: int = -99
var cost_override_this_combat: int = -99
## The deck copy this combat clone came from (null for generated cards).
var source: CardInstance


func _init(card_data: CardData, is_upgraded: bool = false) -> void:
	data = card_data
	upgraded = is_upgraded
	uid = _next_uid
	_next_uid += 1


func get_cost() -> int:
	if cost_override_this_turn != -99:
		return cost_override_this_turn
	if cost_override_this_combat != -99:
		return cost_override_this_combat
	return data.get_cost(upgraded)


func get_display_name() -> String:
	return data.display_name + ("+" if upgraded else "")


func has_keyword(keyword: StringName) -> bool:
	return data.has_keyword(keyword, upgraded)


func can_upgrade() -> bool:
	return data.can_upgrade and not upgraded


func upgrade() -> void:
	if can_upgrade():
		upgraded = true


func clone_for_combat() -> CardInstance:
	var copy := CardInstance.new(data, upgraded)
	copy.source = self
	return copy


func to_dict() -> Dictionary:
	return {"id": String(data.id), "up": upgraded}


## Needs ContentDB to resolve the id; returns null for unknown ids so old saves
## survive removed content.
static func from_dict(entry: Dictionary, card_lookup: Callable) -> CardInstance:
	var card: CardData = card_lookup.call(StringName(entry.get("id", "")))
	if card == null:
		push_warning("CardInstance: unknown card id '%s' in save" % entry.get("id", ""))
		return null
	return CardInstance.new(card, bool(entry.get("up", false)))
