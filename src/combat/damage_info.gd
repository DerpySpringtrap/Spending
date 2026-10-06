class_name DamageInfo
extends RefCounted
## Record of one damage event. Emitted through EventBus.damage_dealt with all
## post-change values, so presentation never has to read live combat state.

enum Type {
	ATTACK,   ## Affected by Strength/Weak/Vulnerable; triggers ATTACKED.
	THORNS,   ## Reactive damage. Blockable, unmodified.
	BURN,     ## Blockable, unmodified.
	POISON,   ## Ignores Block.
	HP_LOSS,  ## Ignores Block (self-damage costs, Overheat recoil).
	OTHER,    ## Blockable, unmodified (Overheat blast, relic damage).
}

var source: Combatant
var target: Combatant
var type: Type = Type.ATTACK
var base: int = 0
## Final damage after modifiers, before Block.
var amount: int = 0
var blocked: int = 0
var hp_lost: int = 0
var block_before: int = 0
var block_after: int = 0
var hp_after: int = 0
var killed: bool = false


func is_attack() -> bool:
	return type == Type.ATTACK


static func ignores_block(damage_type: Type) -> bool:
	return damage_type == Type.POISON or damage_type == Type.HP_LOSS
