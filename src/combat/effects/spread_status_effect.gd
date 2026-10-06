@tool
class_name SpreadStatusEffect
extends GameEffect
## "Every other enemy gains <status> equal to the target's <status>."

@export var status: StatusEffectData


func execute(ctx: EffectContext) -> void:
	var origin := ctx.chosen_target
	if origin == null or status == null:
		return
	var stacks := origin.get_stacks(status.id)
	if stacks <= 0:
		return
	for other in ctx.combat.living_allies_of(origin):
		if other != origin:
			ctx.combat.apply_status(other, status, stacks, ctx.source)
