class_name RelicIcon
extends Control
## Relic in the relic bar: a medallion with the relic's icon (or initial),
## tooltip with description and flavour, and a flash when it triggers.

var relic: RelicData
var _flash := 0.0:
	set(v):
		_flash = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(48, 48)
	pivot_offset = Vector2(24, 24)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	mouse_entered.connect(func():
		var body := relic.description
		if not relic.flavor.is_empty():
			body += "\n\n[i][color=#%s]%s[/color][/i]" % [UIStyle.TEXT_DIM.to_html(false), relic.flavor]
		EventBus.tooltip_requested.emit(self, relic.display_name, body))
	mouse_exited.connect(func(): EventBus.tooltip_cleared.emit(self))


func flash() -> void:
	_flash = 1.0
	scale = Vector2(1.3, 1.3)
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "_flash", 0.0, UIStyle.dur(0.5))
	t.tween_property(self, "scale", Vector2.ONE, UIStyle.dur(0.3)).set_trans(Tween.TRANS_BACK)


func _draw() -> void:
	var c := size / 2
	if _flash > 0.0:
		draw_circle(c, 26 + _flash * 6, Color(UIStyle.GOLD, 0.5 * _flash))
	draw_circle(c, 22, UIStyle.OUTLINE)
	draw_circle(c, 20, UIStyle.GOLD.darkened(0.35))
	draw_circle(c, 16, UIStyle.PANEL_HI)
	if relic.icon:
		draw_texture_rect(relic.icon, Rect2(c - Vector2(14, 14), Vector2(28, 28)), false)
	else:
		var f := UIStyle.display_font()
		var letter := relic.display_name.left(1)
		var ts := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		draw_string(f, c + Vector2(-ts.x / 2, 8), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UIStyle.GOLD)
