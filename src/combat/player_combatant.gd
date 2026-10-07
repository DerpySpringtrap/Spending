class_name PlayerCombatant
extends Combatant
## The hero in combat. Energy and the class resource live here; the card
## piles live on CombatState.

var class_data: CharacterClassData
var energy: int = 0
## Current value of the class's secondary resource (Heat, Ink, Sap...).
var resource_value: int = 0
## Current phase (Moonblade): the active stance status, or null.
var stance: StatusEffectData
## Which PlayerSeat (hero) this is; 0 in solo.
var seat_index: int = 0


func _init(p_class: CharacterClassData, p_hp: int, p_max_hp: int) -> void:
	super(p_class.display_name, Side.PLAYER, p_max_hp, p_hp)
	class_data = p_class


func get_resource_data() -> ClassResourceData:
	return class_data.secondary_resource
