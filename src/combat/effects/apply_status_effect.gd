@tool
class_name ApplyStatusEffect
extends GameEffect
## "Apply X <status>". Negative amounts reduce stacks (e.g. "-2 Strength").
## Power cards are ApplyStatus on SELF.

@export var status: StatusEffectData


func execute(ctx: EffectContext) -> void:
	if status == null:
		push_error("ApplyStatusEffect without a status")
		return
	var amount := ctx.amount_for(self)
	for i in times:
		for target_combatant in ctx.resolve_targets(self):
			ctx.combat.apply_status(target_combatant, status, amount, ctx.source)


func per_player() -> bool:
	return target == Target.CHOSEN
