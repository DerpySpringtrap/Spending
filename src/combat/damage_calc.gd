class_name DamageCalc
extends RefCounted
## The single damage/block pipeline. Used for real resolution AND for every
## preview (card numbers, intent numbers), so what the player sees is exactly
## what happens.
##
## Attack order: base + attacker flat (Strength, phase bonuses)
##   × attacker multipliers (Weak) × defender multipliers (Vulnerable)
##   + defender flat → floor → min 0.

const EPSILON := 0.0001


static func attack_damage(base: int, source: Combatant, target: Combatant) -> int:
	var dmg := float(base)
	if source != null:
		dmg += source.stat_flat(&"damage_dealt_flat_per_stack")
		dmg *= source.stat_mult(&"damage_dealt_multiplier")
	if target != null:
		dmg *= target.stat_mult(&"damage_taken_multiplier")
		dmg += target.stat_flat(&"damage_taken_flat_per_stack")
	return maxi(0, floori(dmg + EPSILON))


static func block_amount(base: int, target: Combatant) -> int:
	if target == null:
		return maxi(0, base)
	var amount := float(base) + target.stat_flat(&"block_gained_flat_per_stack")
	amount *= target.stat_mult(&"block_gained_multiplier")
	return maxi(0, floori(amount + EPSILON))
