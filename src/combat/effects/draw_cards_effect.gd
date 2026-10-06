@tool
class_name DrawCardsEffect
extends GameEffect
## "Draw X cards".


func execute(ctx: EffectContext) -> void:
	ctx.combat.draw_cards(ctx.amount_for(self))
