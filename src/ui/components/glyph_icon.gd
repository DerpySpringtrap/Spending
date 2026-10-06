class_name GlyphIcon
extends Control
## A VectorIcons glyph as a Control, for use inside containers (top bar etc.).

@export var glyph: StringName = &"star"
@export var color: Color = Color.WHITE


static func make(p_glyph: StringName, p_color: Color, px: float = 26.0) -> GlyphIcon:
	var icon := GlyphIcon.new()
	icon.glyph = p_glyph
	icon.color = p_color
	icon.custom_minimum_size = Vector2(px, px)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _draw() -> void:
	VectorIcons.draw(self, glyph, size / 2, minf(size.x, size.y), color)
