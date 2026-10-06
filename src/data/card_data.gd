@tool
class_name CardData
extends Resource
## Static definition of a card. One .tres per card under
## res://content/classes/<class>/cards/ or res://content/cards/<pool>/.
##
## Runtime copies (with upgrade state, temporary cost changes, unique ids) are
## CardInstance objects that reference this resource.

enum CardType { ATTACK, SKILL, POWER, STATUS, CURSE }
enum Rarity { STARTER, COMMON, UNCOMMON, RARE, SPECIAL }
enum TargetMode {
	NONE,          ## No target (draw, energy...): drag anywhere above the hand.
	SINGLE_ENEMY,  ## Shows the targeting arrow.
	ALL_ENEMIES,   ## Highlights every enemy (AoE play visual).
	RANDOM_ENEMY,
	SELF,
	SINGLE_ALLY,   ## Pick one of the player's summons (Rootmother).
}

const COST_X := -1           ## Spends all energy; effects read X from the context.
const COST_UNPLAYABLE := -2  ## Curses and most status cards.
const NO_UPGRADE_COST := -99

## Keywords understood by the combat engine.
const KW_EXHAUST := &"exhaust"   ## Shown to players as "Erase" for the Scribe theme.
const KW_RETAIN := &"retain"
const KW_INNATE := &"innate"
const KW_ETHEREAL := &"ethereal"

@export var id: StringName
@export var display_name: String
## Template text. {key} tokens are replaced by live values from the effect
## whose value_key matches, e.g. "Deal {dmg} damage. Stoke {heat}."
@export_multiline var description: String
@export var art: Texture2D
## Class id (&"pyre_warden"), or &"neutral", &"curse", &"status".
@export var card_pool: StringName = &"neutral"
@export var type: CardType = CardType.ATTACK
@export var rarity: Rarity = Rarity.COMMON
@export var target_mode: TargetMode = TargetMode.SINGLE_ENEMY
@export_range(-2, 9) var cost: int = 1
@export var effects: Array[GameEffect] = []
@export var keywords: Array[StringName] = []
## Free-form synergy tags (&"burn", &"heat", &"summon", &"strike"...). Used by
## "whenever you play a Strike"-style triggers and by reward weighting.
@export var tags: Array[StringName] = []
## Effects that run when the card is discarded manually (Scribe "Footnote").
@export var on_discard_effects: Array[GameEffect] = []
## Effects that run if the card is still in hand at end of turn (curses/status).
@export var end_of_turn_in_hand_effects: Array[GameEffect] = []

@export_group("Upgrade")
@export var can_upgrade: bool = true
@export_range(-99, 9) var upgraded_cost: int = NO_UPGRADE_COST
## If non-empty, replaces the description when upgraded (otherwise the same
## template is reused and just shows the bigger numbers).
@export_multiline var upgraded_description: String
@export var upgrade_adds_keywords: Array[StringName] = []
@export var upgrade_removes_keywords: Array[StringName] = []

@export_group("Presentation")
## Optional per-card overrides; otherwise class/type defaults are used.
@export var play_sfx: AudioStream
@export var impact_vfx: PackedScene
## Plays the class motif accent (powers / signature rares).
@export var plays_class_motif: bool = false

@export_group("Class mechanics")
## Moonfall: costs this much less for each phase change this turn.
@export var cost_reduction_per_stance_change: int = 0


func get_cost(upgraded: bool) -> int:
	if upgraded and upgraded_cost != NO_UPGRADE_COST:
		return upgraded_cost
	return cost


func get_keywords(upgraded: bool) -> Array[StringName]:
	var result: Array[StringName] = keywords.duplicate()
	if upgraded:
		for kw in upgrade_adds_keywords:
			if not result.has(kw):
				result.append(kw)
		for kw in upgrade_removes_keywords:
			result.erase(kw)
	return result


func has_keyword(keyword: StringName, upgraded: bool) -> bool:
	return get_keywords(upgraded).has(keyword)


func is_playable_type() -> bool:
	return cost != COST_UNPLAYABLE


func get_description_template(upgraded: bool) -> String:
	if upgraded and not upgraded_description.is_empty():
		return upgraded_description
	return description
