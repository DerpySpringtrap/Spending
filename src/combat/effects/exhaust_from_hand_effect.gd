@tool
class_name ExhaustFromHandEffect
extends GameEffect
## Erases (exhausts) every card in hand matching [member card_types] (empty =
## any type), then runs [member per_card_effects] once per card erased.
## "Erase all Curses and Statuses in your hand. Gain 3 Ink and 5 Block for each."

@export var card_types: Array[CardData.CardType] = []
@export var per_card_effects: Array[GameEffect] = []


func execute(ctx: EffectContext) -> void:
	var combat := ctx.combat
	var picked: Array[CardInstance] = []
	for card in combat.hand:
		if card_types.is_empty() or card_types.has(card.data.type):
			picked.append(card)
	for card in picked:
		if combat.is_over():
			return
		combat.exhaust_card(card)
		for effect in per_card_effects:
			effect.execute(ctx)


func get_sub_effects() -> Array[GameEffect]:
	return per_card_effects
