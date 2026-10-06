@tool
class_name EventOutcome
extends Resource
## One consequence of an event choice.

enum Type {
	GAIN_GOLD,
	LOSE_GOLD,
	HEAL,
	LOSE_HP,
	GAIN_MAX_HP,
	LOSE_MAX_HP,
	GAIN_CARD,             ## A specific card (curses, special cards).
	GAIN_RANDOM_CARD,      ## A random class card of [member rarity].
	REMOVE_CARD,           ## Player chooses a card to remove.
	UPGRADE_CARD,          ## Player chooses a card to upgrade.
	UPGRADE_RANDOM_CARDS,  ## [member amount] random upgradable cards.
	GAIN_RELIC,            ## Random relic of [member relic_rarity].
	GAIN_POTION,           ## [member amount] random potions.
	FIGHT,                 ## Starts [member encounter]; rewards include a relic.
}

@export var type: Type = Type.GAIN_GOLD
@export var amount: int = 0
## HEAL / LOSE_HP / max HP: amount is a percentage of max HP.
@export var percent: bool = false
@export var card: CardData
@export var rarity: CardData.Rarity = CardData.Rarity.COMMON
@export var relic_rarity: RelicData.Rarity = RelicData.Rarity.COMMON
@export var encounter: EncounterData
