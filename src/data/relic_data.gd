@tool
class_name RelicData
extends Resource
## A passive, run-long item. Relics reuse EffectTrigger, so "At the start of
## combat, gain 3 Heat" is just a COMBAT_START trigger with a GainResource effect.

enum Rarity { STARTER, COMMON, UNCOMMON, RARE, BOSS, SHOP, EVENT, SPECIAL }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Italic flavour line under the description in tooltips.
@export_multiline var flavor: String
@export var icon: Texture2D
@export var rarity: Rarity = Rarity.COMMON
## &"" = any class; otherwise only offered to that class.
@export var class_restriction: StringName = &""
@export var triggers: Array[EffectTrigger] = []
## Visible counter on the relic icon (e.g. "every 3rd attack"). 0 = none.
@export var counter_max: int = 0

@export_group("Passive run modifiers")
@export var max_energy_bonus: int = 0
@export var draw_per_turn_bonus: int = 0
@export var max_hp_bonus: int = 0
@export var potion_slot_bonus: int = 0
@export_range(0.0, 3.0) var gold_gain_multiplier: float = 1.0
@export_range(0.0, 3.0) var shop_price_multiplier: float = 1.0

## Escape hatch for relics the declarative fields can't express.
@export var behavior_script: Script

@export_group("Meta")
## Must be unlocked through meta-progression before it can drop.
@export var requires_unlock: bool = false
## Class level (MetaProgress) needed before this relic can drop. Checked
## against the current run's class. 1 = available from the start.
@export_range(1, 10) var unlock_level: int = 1
