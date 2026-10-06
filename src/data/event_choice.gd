@tool
class_name EventChoice
extends Resource
## A button in an event: label, requirements, outcomes and the text shown after.

## Button label, e.g. "[Pray] Lose 7 HP. Gain a relic."
@export var text: String
@export_multiline var result_text: String
@export var outcomes: Array[EventOutcome] = []
## The choice is disabled unless the player has at least this much gold.
@export var min_gold: int = 0
## The choice is disabled unless the player has MORE than this much HP.
@export var min_hp: int = 0
