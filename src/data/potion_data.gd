@tool
class_name PotionData
extends Resource
## A single-use consumable. Usable any time during the player's turn in combat;
## some (healing) can also be used on the map.

enum Rarity { COMMON, UNCOMMON, RARE }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
## Liquid colour for the bottle shader / pour VFX.
@export var liquid_color: Color = Color(0.8, 0.2, 0.2)
@export var rarity: Rarity = Rarity.COMMON
@export var class_restriction: StringName = &""
@export var target_mode: CardData.TargetMode = CardData.TargetMode.NONE
@export var effects: Array[GameEffect] = []
@export var usable_outside_combat: bool = false
