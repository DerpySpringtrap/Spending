@tool
class_name ChooseCardsEffect
extends GameEffect
## The player picks cards, then something happens to them: discard from hand
## (Footnotes trigger), Erase/Exhaust from hand, or move from the draw pile to
## the hand. [member amount] = how many.
##
## In the combat screen this pauses the card until the player chooses; the
## effects listed after this one on the card run once the choice is made, with
## X = the number of cards chosen ("Discard up to 3 cards. Draw that many.").
## Put choice effects at the top level of a card's effect list.
## AI, simulations and tests choose automatically (CombatState.auto_choose).

enum Mode { DISCARD, EXHAUST, DRAW_TO_HAND }

@export var mode: Mode = Mode.DISCARD
## True = choose 0 up to [member amount]; false = exactly [member amount] (or
## every option, if there are fewer).
@export var up_to: bool = false
## Shown above the picker. Empty = generated from the mode.
@export var prompt: String = ""


func execute(ctx: EffectContext) -> void:
	if ctx.source == ctx.combat.player:
		ctx.combat.request_choice(self, ctx)


func get_prompt(count: int) -> String:
	if not prompt.is_empty():
		return prompt
	var noun := "card" if count == 1 else "cards"
	var limit := ("up to %d" if up_to else "%d") % count
	match mode:
		Mode.EXHAUST:
			return "Erase %s %s" % [limit, noun]
		Mode.DRAW_TO_HAND:
			return "Put %s %s from your draw pile into your hand" % [limit, noun]
	return "Discard %s %s" % [limit, noun]
