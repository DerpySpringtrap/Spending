@tool
class_name StatusEffectData
extends Resource
## Definition of a buff/debuff (Poison, Weak, Strength, Burn, Stun...).
##
## About 90% of statuses need only the declarative fields below: stat modifiers
## for the damage/block pipeline, a decay rule, and triggers. Statuses that need
## bespoke logic can point [member behavior_script] at a StatusBehavior subclass
## (Milestone 1) without changing the combat code.

enum Kind { BUFF, DEBUFF, NEUTRAL }

enum StackMode {
	INTENSITY, ## Stacks add together and scale the effect (Strength, Poison).
	DURATION,  ## Stacks are turns remaining (Weak, Vulnerable).
	COUNTER,   ## Counts up toward a threshold (e.g. "every 3 cards").
	FLAG,      ## On/off; extra applications are ignored (Barricade-like).
}

enum Decay {
	NONE,
	DECREMENT_ON_TURN_START,
	DECREMENT_ON_TURN_END,
	REMOVE_ON_TURN_END,
	HALVE_ON_TURN_END,    ## Burn: big upfront damage that burns out quickly.
	## Weak/Vulnerable/Frail: -1 after every combatant has acted. Applied
	## during the enemy phase, the first decrement is skipped, so "1 Weak" from
	## an enemy always covers the player's next turn.
	DECREMENT_ON_ROUND_END,
	DECREMENT_ON_TRIGGER, ## Lose one stack each time a trigger fires.
	REMOVE_ON_TRIGGER,
	REMOVE_ON_TURN_START, ## Lasts until the owner's next turn (enemy "this turn" buffs).
}

@export var id: StringName
@export var display_name: String
## Supports {stacks}. Example: "At the start of its turn, loses {stacks} HP."
@export_multiline var description: String
@export var icon: Texture2D
@export var kind: Kind = Kind.DEBUFF
@export var stack_mode: StackMode = StackMode.INTENSITY
@export var decay: Decay = Decay.NONE
@export var max_stacks: int = 999
## Strength/Dexterity can go below zero; most statuses are removed at 0.
@export var allow_negative: bool = false
## Shown in tooltips; hidden statuses are used for internal bookkeeping.
@export var hidden: bool = false

@export_group("Stat modifiers")
## Flat damage added to each hit the owner deals, per stack (Strength = 1).
@export var damage_dealt_flat_per_stack: int = 0
## Multiplier on damage the owner deals (Weak = 0.75). Not per-stack.
@export var damage_dealt_multiplier: float = 1.0
## Multiplier on damage the owner takes (Vulnerable = 1.5). Not per-stack.
@export var damage_taken_multiplier: float = 1.0
## Flat change to each hit the owner takes, per stack (negative = reduction).
@export var damage_taken_flat_per_stack: int = 0
## Block added to each block gain, per stack (Dexterity = 1).
@export var block_gained_flat_per_stack: int = 0
## Multiplier on block gained (Frail = 0.75).
@export var block_gained_multiplier: float = 1.0
## Block isn't removed at the start of the owner's turn.
@export var retains_block: bool = false
## The owner skips its next action (Stun). Enemies show a "Stunned" intent.
@export var skips_turn: bool = false
## Cheat death once (Gilded Skeleton's Reassemble): on a lethal hit the owner
## revives at this fraction of max HP, stunned for a turn, and loses the
## status. Only while another enemy is still standing. 0 = off.
@export_range(0.0, 1.0) var revive_hp_percent: float = 0.0
## Loses 1 stack whenever the owner loses HP (Gilded Plate: hits strip it).
@export var lose_stack_on_hp_lost: bool = false
## The owner heals this fraction of the HP damage its attacks deal (Vampiric).
@export_range(0.0, 1.0) var attack_lifesteal: float = 0.0
## Bonus clauses paid with the class resource (Vent/Inscribe/Graft) cost this
## much less, per stack (Living Manuscript).
@export var resource_cost_reduction_per_stack: int = 0
## Run when the stacks reach [member max_stacks]; then the stacks reset to 0
## (the Umbral Sovereign's Umbra meter → Total Darkness).
@export var max_stack_effects: Array[GameEffect] = []
## At Ascension 15, the cap used for [member max_stack_effects] (0 = unchanged).
@export var a15_max_stacks: int = 0
## Extra/fewer cards drawn per turn (player only), per stack.
@export var draw_per_turn_per_stack: int = 0
## Extra/less energy per turn (player only), per stack.
@export var energy_per_turn_per_stack: int = 0

@export_group("Triggers")
@export var triggers: Array[EffectTrigger] = []
## Escape hatch for statuses the declarative fields can't express.
@export var behavior_script: Script

@export_group("Presentation")
@export var tint: Color = Color.WHITE
@export var apply_vfx: PackedScene
@export var proc_vfx: PackedScene
@export var apply_sfx: AudioStream
@export var proc_sfx: AudioStream


func format_description(stacks: int) -> String:
	return description.replace("{stacks}", str(stacks))
