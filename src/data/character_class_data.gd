@tool
class_name CharacterClassData
extends Resource
## Everything that defines a playable class. One per class at
## res://content/classes/<class_id>/class.tres.

@export var id: StringName
@export var display_name: String
@export var title: String  ## e.g. "Keeper of the Last Ember"
@export_multiline var description: String

@export_group("Stats")
@export var max_hp: int = 75
@export var starting_gold: int = 99
@export var energy_per_turn: int = 3
@export var cards_per_turn: int = 5
@export var max_hand_size: int = 10

@export_group("Loadout")
@export var starting_deck: Array[CardData] = []
@export var starting_relic: RelicData
@export var secondary_resource: ClassResourceData
## Optional stance/phase definitions (Moonblade). Each is a status applied as a
## FLAG while the stance is active, so stance bonuses use the status pipeline.
@export var stances: Array[StatusEffectData] = []
## Moonblade: changing phase at max class resource enters this stance instead
## (both phase bonuses). It ends at the end of the turn and resets the resource.
@export var eclipse_stance: StatusEffectData
## Effects run on entering the eclipse stance (draw 2).
@export var eclipse_effects: Array[GameEffect] = []

@export_group("Presentation")
@export var primary_color: Color = Color.WHITE
@export var secondary_color: Color = Color.GRAY
@export var accent_color: Color = Color.GOLD
@export var card_frame: Texture2D
@export var portrait: Texture2D
@export var select_screen_art: Texture2D
## Combat scene with the hero's sprite, AnimationPlayer and anchors.
@export var combat_scene: PackedScene
## Short musical accent layered over the music when signature cards are played.
@export var motif_stream: AudioStream
## Default SFX when this class plays an Attack / Skill / Power.
@export var attack_sfx: Array[AudioStream] = []
@export var skill_sfx: AudioStream
@export var power_sfx: AudioStream

@export_group("Meta")
@export var unlocked_by_default: bool = false
@export_multiline var unlock_hint: String
