@tool
class_name ClassResourceData
extends Resource
## Describes a class's secondary resource (Heat, Lunar Charge, Ink, Sap) so the
## generic combat UI can draw a gauge for it and effects can reference it by id.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var color: Color = Color.WHITE
@export var max_value: int = 10
@export var starting_value: int = 0
## If false, the value resets to [member starting_value] at the start of each turn.
@export var persists_between_turns: bool = true
## Effects run when the value reaches max (Pyre Warden: Overheat).
## Leave empty for resources without a cap event.
@export var on_reach_max_effects: Array[GameEffect] = []
## When on_reach_max_effects fire: immediately, or at the end of the turn.
@export var max_triggers_at_turn_end: bool = true
