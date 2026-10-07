@tool
class_name GainMaxHpEffect
extends GameEffect
## Raises the target's max HP by X for this combat and heals that much
## (Nourish on summons, the Elder Treant growing).


func execute(ctx: EffectContext) -> void:
	var amount := ctx.amount_for(self)
	if amount <= 0:
		return
	for target_combatant in ctx.resolve_targets(self):
		target_combatant.max_hp += amount
		ctx.combat.heal(target_combatant, amount)
