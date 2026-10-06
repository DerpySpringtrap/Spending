@tool
class_name EventData
extends Resource
## A narrative "?" node: text, art and a list of choices.

@export var id: StringName
@export var title: String
@export_multiline var description: String
@export var act: int = 1
@export var art: Texture2D
## Placeholder art glyph (VectorIcons) used when [member art] is empty.
@export var glyph: StringName = &"question"
@export var choices: Array[EventChoice] = []
