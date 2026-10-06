class_name TurnBanner
extends Control
## Full-width banner that sweeps across the screen ("Your Turn", "Enemy Turn",
## "Overheat!").

var _band: ColorRect
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_band = ColorRect.new()
	_band.color = Color(UIStyle.BG_DEEP, 0.78)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", UIStyle.display_font())
	_label.add_theme_font_size_override("font_size", UIStyle.SIZE_BANNER)
	UIStyle.outline_label(_label, 12)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	visible = false


func show_banner(text: String, color: Color = UIStyle.GOLD, hold: float = 0.45) -> void:
	var view := get_viewport_rect().size
	_band.size = Vector2(view.x, 120)
	_band.position = Vector2(0, view.y * 0.42 - 60)
	_label.size = _band.size
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	visible = true
	modulate.a = 0.0
	_label.position = _band.position + Vector2(-120, 0)
	_band.scale = Vector2(1, 0.2)
	_band.pivot_offset = _band.size / 2
	var out_at := UIStyle.dur(0.25 + hold)
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, UIStyle.dur(0.15))
	t.tween_property(_band, "scale", Vector2.ONE, UIStyle.dur(0.18))
	t.tween_property(_label, "position:x", 0.0, UIStyle.dur(0.25))
	t.tween_property(self, "modulate:a", 0.0, UIStyle.dur(0.2)).set_delay(out_at).set_ease(Tween.EASE_IN)
	t.tween_property(_label, "position:x", 120.0, UIStyle.dur(0.2)).set_delay(out_at).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(func(): visible = false)
