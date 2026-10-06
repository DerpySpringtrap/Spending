@tool
class_name GainClassResourceEffect
extends GameEffect
## Gain (or lose, if negative) the class resource unconditionally:
## Stoke X (Heat), gain X Ink, gain X Sap.


func execute(ctx: EffectContext) -> void:
	ctx.combat.change_class_resource(ctx.amount_for(self))
