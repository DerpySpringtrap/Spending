@tool
class_name AddCardToPileEffect
extends GameEffect
## "Shuffle X <card> into your draw pile" / "Add X <card> to your hand".
## Amount = number of copies. Used by enemies to clutter the player's deck.

@export var card: CardData
@export var pile: CombatState.Pile = CombatState.Pile.DISCARD
@export var upgraded: bool = false


func execute(ctx: EffectContext) -> void:
	if card == null:
		push_error("AddCardToPileEffect without a card")
		return
	for i in maxi(ctx.amount_for(self), 1):
		ctx.combat.add_card_to_pile(card, pile, upgraded)
