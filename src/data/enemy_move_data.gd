@tool
class_name EnemyMoveData
extends Resource
## One move in an enemy's repertoire, with the intent it telegraphs.

enum Intent {
	ATTACK,
	ATTACK_DEFEND,
	ATTACK_BUFF,
	ATTACK_DEBUFF,
	DEFEND,
	DEFEND_BUFF,
	BUFF,
	DEBUFF,
	STRONG_DEBUFF,
	SUMMON,
	CHARGING,  ## Winding up a big move; shown with a countdown.
	ESCAPE,
	STUNNED,
	SPECIAL,   ## Unique gimmick moves (Rewind, Reassemble...). Tooltip explains.
	UNKNOWN,   ## Deliberately hidden (rare, used for surprise gimmicks).
}

@export var id: StringName
@export var display_name: String
@export var intent: Intent = Intent.ATTACK
## Tooltip shown when hovering the intent icon. Supports {dmg} and {times}.
@export_multiline var intent_tooltip: String
@export var effects: Array[GameEffect] = []

@export_group("Selection rules")
## Weight when the phase uses weighted-random selection.
@export_range(0.0, 100.0) var weight: float = 1.0
## The move can't be chosen more than this many times in a row (0 = no limit).
@export var max_consecutive: int = 0
## Turns the move must wait after use before it can be chosen again.
@export var cooldown: int = 0
## If > 0, the move is only legal from this turn number onward.
@export var min_turn: int = 0

@export_group("Ascension")
## Ascension level at which [member ascension_amount_bonus] kicks in (0 = never).
@export var ascension_threshold: int = 0
## Added to every damage/block/stack amount of this move at or above the threshold.
@export var ascension_amount_bonus: int = 0

@export_group("Presentation")
## Name of the animation on the enemy's AnimationPlayer ("attack", "cast"...).
@export var animation: StringName = &"attack"
@export var sfx: AudioStream
@export var vfx: PackedScene
## Big moves get extra hit-stop and screen shake.
@export var is_heavy: bool = false
