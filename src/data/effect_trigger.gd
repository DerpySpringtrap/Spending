@tool
class_name EffectTrigger
extends Resource
## "When <timing> happens, run <effects>."
##
## Shared by status effects, Power cards (which are just statuses applied to
## yourself), relics and enemy passives, so every reactive rule in the game is
## authored the same way.

enum Timing {
	# Combat flow
	COMBAT_START,
	COMBAT_END,
	TURN_START,           ## Owner's turn starts (after block reset, before draw).
	TURN_START_POST_DRAW, ## Owner's turn starts, after the hand is drawn.
	TURN_END,             ## Owner's turn ends (before discarding the hand).
	ROUND_END,            ## After every combatant has acted.
	# Card events (owner = the player)
	CARD_PLAYED,
	ATTACK_PLAYED,
	SKILL_PLAYED,
	POWER_PLAYED,
	CARD_DRAWN,
	CARD_DISCARDED,       ## Manual discard only (not the end-of-turn hand discard).
	CARD_EXHAUSTED,
	DECK_SHUFFLED,
	# Damage events
	ATTACKED,             ## Owner is hit by an attack (fires even if fully blocked).
	HP_LOST,              ## Owner loses HP from any source.
	BLOCK_BROKEN,
	DEALT_ATTACK_DAMAGE,
	STATUS_APPLIED_TO_OWNER,
	OWNER_APPLIED_STATUS,
	ENEMY_DIED,
	OWNER_DIED,
	# Class mechanics
	CLASS_RESOURCE_GAINED,
	CLASS_RESOURCE_SPENT,
	STANCE_CHANGED,
	SUMMON_CREATED,
	SUMMON_DIED,
	# Run-level (relics only)
	PICKED_UP,
	REST_SITE_ENTERED,
	SHOP_ENTERED,
	MAP_NODE_ENTERED,
}

## Extra condition evaluated when the event happens (not when the queued
## reaction later resolves).
enum Condition {
	NONE,
	HIT_WHILE_BLOCKING, ## ATTACKED only: the owner had Block when hit.
	UNBLOCKED_HIT,      ## ATTACKED only: the hit dealt HP damage.
	REQUIRES_STATUS,    ## The owner has [member required_status_id] (a phase counts while in Eclipse).
	FIRST_TURN,         ## Only during the first round of combat.
}

@export var timing: Timing = Timing.TURN_START
@export var condition: Condition = Condition.NONE
@export var effects: Array[GameEffect] = []
## When true, effect amounts are replaced by the owner's current stack count
## (Poison: lose HP equal to stacks; Thorns: deal damage equal to stacks).
@export var amount_from_stacks: bool = false
## Only fire every Nth time (relics like "every 3rd Attack played"). 1 = always.
@export_range(1, 99) var every_nth: int = 1
## Optional filter: only fire if the triggering card has this tag.
@export var required_card_tag: StringName = &""
## Status id checked by Condition.REQUIRES_STATUS.
@export var required_status_id: StringName = &""
## Fires at most once per turn ("the first time you change phase each turn").
@export var once_per_turn: bool = false
## Optional filter: only fire if the triggering card is of this
## CardData.CardType (-1 = any). "Whenever you draw a Curse..."
@export var required_card_type: int = -1
## Optional second type accepted alongside [member required_card_type].
@export var required_card_type_alt: int = -1
