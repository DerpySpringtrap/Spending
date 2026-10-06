@tool
class_name EnemyPhaseData
extends Resource
## A behaviour phase. Normal enemies have one phase; bosses switch phases when
## their HP drops below a threshold (or when a custom condition fires).

enum Selection {
	SEQUENCE,        ## Loop through [member moves] in order.
	WEIGHTED_RANDOM, ## Weighted pick that respects max_consecutive and cooldowns.
	SCRIPTED,        ## Delegates to [member ai_script] (an EnemyAI subclass).
}

@export var display_name: String
## The phase becomes active when HP% drops to or below this value (1.0 = start).
@export_range(0.0, 1.0) var hp_threshold: float = 1.0
@export var selection: Selection = Selection.WEIGHTED_RANDOM
@export var moves: Array[EnemyMoveData] = []
## Fixed moves used on the first turns of the phase before normal selection.
@export var opening_moves: Array[EnemyMoveData] = []
## Run once when the phase starts (heal, clear debuffs, summon adds...).
@export var on_enter_effects: Array[GameEffect] = []
## Passive rules active during this phase (e.g. "gains 2 Strength whenever
## you play a Skill").
@export var passive_triggers: Array[EffectTrigger] = []
@export var ai_script: Script

@export_group("Presentation")
## Bosses: plays the phase-transition cinematic/animation and swaps music layer.
@export var transition_animation: StringName = &""
@export var music_layer: StringName = &""
