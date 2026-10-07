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


## The fixed cost after discounts (Living Manuscript).
func cost(ctx: EffectContext) -> int:
	var discount := int(ctx.combat.player.stat_flat(&"resource_cost_reduction_per_stack"))
	return maxi(0, ctx.amount_for(self) - discount)


func is_affordable(ctx: EffectContext) -> bool:
	var available := ctx.combat.player.resource_value
	return available > 0 if spend_all else available >= cost(ctx)


func execute(ctx: EffectContext) -> void:
	if not is_affordable(ctx):
		return
	var price := ctx.combat.player.resource_value if spend_all else cost(ctx)
	var spent := -ctx.combat.change_class_resource(-price)
	var sub := ctx.duplicate_context()
	sub.x_value = spent
	for effect in bonus_effects:
		if ctx.combat.is_over():
			return
		effect.execute(sub)


## Context used to preview the bonus (X = what would be spent right now).
func make_preview_context(ctx: EffectContext) -> EffectContext:
	var sub := ctx.duplicate_context()
	sub.x_value = ctx.combat.player.resource_value if spend_all else cost(ctx)
	return sub


func get_sub_effects() -> Array[GameEffect]:
	return bonus_effects


## Card text shows the discounted cost.
func preview_amount(ctx: EffectContext) -> int:
	return cost(ctx)
