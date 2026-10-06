@tool
class_name GainBlockEffect
extends GameEffect
## "Gain X Block". Set target = SELF for cards and enemy moves.


func execute(ctx: EffectContext) -> void:
	var amount := ctx.amount_for(self)
	for i in times:
		for target_combatant in ctx.resolve_targets(self):
			ctx.combat.gain_block(target_combatant, amount)


func preview_amount(ctx: EffectContext) -> int:
	return DamageCalc.block_amount(ctx.amount_for(self), ctx.source)
