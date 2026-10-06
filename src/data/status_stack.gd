@tool
class_name StatusStack
extends Resource
## A (status, stacks) pair, used for authoring starting statuses on enemies,
## summons and in tests.

@export var status: StatusEffectData
@export var stacks: int = 1
