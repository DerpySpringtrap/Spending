@tool
class_name HealEffect
extends GameEffect
## "Heal X HP". Set target = SELF for self-heals.


func execute(ctx: EffectContext) -> void:
	var amount := ctx.amount_for(self)
	for target_combatant in ctx.resolve_targets(self):
		ctx.combat.heal(target_combatant, amount)
