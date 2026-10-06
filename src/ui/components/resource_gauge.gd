class_name ResourceGauge
extends Control
## Class resource gauge (Heat for the Pyre Warden): a row of pips with a
## label. Glows and pulses when full.

var resource: ClassResourceData
var value := 0
var _shown := 0.0:
	set(v):
		_shown = v
		queue_redraw()
var _flash := 0.0:
	set(v):
		_flash = v
		queue_redraw()
var _time := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(250, 64)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	mouse_entered.connect(func():
		if resource:
			EventBus.tooltip_requested.emit(self, resource.display_name, resource.description))
	mouse_exited.connect(func(): EventBus.tooltip_cleared.emit(self))


func setup(p_resource: ClassResourceData, p_value: int) -> void:
	resource = p_resource
	value = p_value
	_shown = p_value
	visible = resource != null


func set_value(p_value: int, _max: int) -> void:
	value = p_value
	create_tween().tween_property(self, "_shown", float(p_value), UIStyle.dur(0.25)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func flash() -> void:
	_flash = 1.0
	create_tween().tween_property(self, "_flash", 0.0, UIStyle.dur(0.6))


func _process(delta: float) -> void:
	_time += delta
	if resource and value >= resource.max_value:
		queue_redraw()


func _draw() -> void:
	if resource == null:
		return
	var n := resource.max_value
	var full := value >= n
	var f := UIStyle.display_font()
	var label := "%s %d/%d" % [resource.display_name, value, n]
	draw_string_outline(f, Vector2(0, 20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, UIStyle.OUTLINE)
	draw_string(f, Vector2(0, 20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, resource.color.lightened(0.3) if full else UIStyle.TEXT)
	var pip_w := minf(22.0, (size.x - (n - 1) * 3.0) / n)
	for i in n:
		var rect := Rect2(Vector2(i * (pip_w + 3.0), 30), Vector2(pip_w, 24))
		var fill := clampf(_shown - i, 0.0, 1.0)
		draw_style_box(UIStyle.box(UIStyle.OUTLINE, 5), rect.grow(2))
		draw_style_box(UIStyle.box(UIStyle.PANEL, 4), rect)
		if fill > 0.0:
			var color := resource.color.lerp(Color("#FFD27A"), float(i) / n)
			if full:
				color = color.lightened(0.15 + 0.15 * sin(_time * 8.0))
			draw_style_box(UIStyle.box(color, 4), Rect2(rect.position + Vector2(0, rect.size.y * (1.0 - fill)), Vector2(rect.size.x, rect.size.y * fill)))
	if _flash > 0.0:
		draw_rect(Rect2(Vector2(-6, 24), Vector2(size.x + 12, 36)), Color(1.0, 0.7, 0.3, _flash * 0.6))
