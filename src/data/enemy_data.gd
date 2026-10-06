@tool
class_name EnemyData
extends Resource
## Definition of an enemy (normal, elite, boss, minion) or a player summon.

enum Tier { NORMAL, ELITE, BOSS, MINION, SUMMON }

@export var id: StringName
@export var display_name: String
@export var tier: Tier = Tier.NORMAL
@export var act: int = 1
@export var hp_min: int = 10
@export var hp_max: int = 12
## Short gimmick line shown in the bestiary and on first encounter.
@export_multiline var gimmick_text: String
@export var starting_statuses: Array[StatusStack] = []
## At least one phase. Bosses list phases in order of descending hp_threshold.
@export var phases: Array[EnemyPhaseData] = []

@export_group("Rewards")
@export var gold_min: int = 10
@export var gold_max: int = 20

@export_group("Presentation")
## Scene with the enemy's sprite/skeleton, AnimationPlayer and anchor markers
## (intent anchor above the head, status tray anchor, hit point for VFX).
@export var visual_scene: PackedScene
@export var portrait: Texture2D
@export var hit_sfx: AudioStream
@export var death_sfx: AudioStream
## Bosses only: plays the intro camera pan and name card.
@export var has_intro_cinematic: bool = false
@export var intro_title: String


func roll_hp(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(hp_min, hp_max)
