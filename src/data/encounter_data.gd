@tool
class_name EncounterData
extends Resource
## A fight: which enemies appear together and which map pool it belongs to.

enum Pool { EASY, HARD, ELITE, BOSS, EVENT }

@export var id: StringName
@export var act: int = 1
@export var pool: Pool = Pool.EASY
@export var enemies: Array[EnemyData] = []
@export_range(0.0, 100.0) var weight: float = 1.0
## Ids of encounters that shouldn't be rolled right after this one (keeps
## consecutive fights varied).
@export var exclusive_with: Array[StringName] = []

@export_group("Presentation")
## Optional override, e.g. a special music track for a set-piece fight.
@export var music_override: AudioStream
@export var background_override: Texture2D
