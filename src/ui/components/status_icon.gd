class_name StatusIcon
extends Control
## One buff/debuff in a tray: tinted disc with a glyph (or the status icon
## texture) and a stack counter. Hover/focus shows the tooltip.

const SIZE := Vector2(34, 34)

var status: StatusEffectData
var stacks := 0
var _pulse := 0.0:
	set(v):
		_pulse = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE / 2
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	mouse_entered.connect(func(): EventBus.tooltip_requested.emit(self, status.display_name, status.format_description(stacks)))
	mouse_exited.connect(func(): EventBus.tooltip_cleared.emit(self))


func set_stacks(value: int, pop: bool) -> void:
	stacks = value
	queue_redraw()
	if pop:
		scale = Vector2(0.4, 0.4) if scale.x < 0.5 else Vector2(1.35, 1.35)
		var t := create_tween()
		t.tween_property(self, "scale", Vector2.ONE, UIStyle.dur(0.2)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func pulse() -> void:
	_pulse = 1.0
	create_tween().tween_property(self, "_pulse", 0.0, UIStyle.dur(0.35))


func _draw() -> void:
	var c := SIZE / 2
	var debuff := status.kind == StatusEffectData.Kind.DEBUFF
	draw_circle(c, 16 + _pulse * 4, Color(status.tint, 0.35 * _pulse))
	draw_circle(c, 15, UIStyle.OUTLINE)
	draw_circle(c, 13, status.tint.darkened(0.55))
	if debuff:
		draw_arc(c, 13, 0, TAU, 24, UIStyle.DEBUFFED.darkened(0.2), 2.0)
	if status.icon:
		draw_texture_rect(status.icon, Rect2(c - Vector2(11, 11), Vector2(22, 22)), false)
	else:
		var glyph := VectorIcons.status_glyph(status)
		if glyph != &"":
			VectorIcons.draw(self, glyph, c, 20, status.tint.lightened(0.25), Color.TRANSPARENT)
		else:
			var f := UIStyle.heavy_font()
			draw_string(f, c + Vector2(-6, 6), status.display_name.left(1), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, status.tint.lightened(0.3))
	if status.stack_mode != StatusEffectData.StackMode.FLAG:
		var f := UIStyle.heavy_font()
		var txt := str(stacks)
		var pos := Vector2(SIZE.x - f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 2, SIZE.y + 2)
		draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, UIStyle.OUTLINE)
		draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIStyle.DEBUFFED if stacks < 0 else Color.WHITE)
