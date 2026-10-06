@tool
class_name SpendClassResourceEffect
extends GameEffect
## A bonus clause paid with the class resource: Vent X (Heat), Inscribe X
## (Ink), Graft X (Sap). If the player can pay [member amount], it is spent
## and [member bonus_effects] run; otherwise the card plays without the bonus.
## With [member spend_all], all of the resource is spent and bonus effects can
## scale with it via Scale.X ("Deal 4 damage per Heat vented").

@export var spend_all: bool = false
@export var bonus_effects: Array[GameEffect] = []


func is_affordable(ctx: EffectContext) -> bool:
	var available := ctx.combat.player.resource_value
	return available > 0 if spend_all else available >= ctx.amount_for(self)


func execute(ctx: EffectContext) -> void:
	if not is_affordable(ctx):
		return
	var cost := ctx.combat.player.resource_value if spend_all else ctx.amount_for(self)
	var spent := -ctx.combat.change_class_resource(-cost)
	var sub := ctx.duplicate_context()
	sub.x_value = spent
	for effect in bonus_effects:
		if ctx.combat.is_over():
			return
		effect.execute(sub)


## Context used to preview the bonus (X = what would be spent right now).
func make_preview_context(ctx: EffectContext) -> EffectContext:
	var sub := ctx.duplicate_context()
	sub.x_value = ctx.combat.player.resource_value if spend_all else ctx.amount_for(self)
	return sub


func get_sub_effects() -> Array[GameEffect]:
	return bonus_effects
