class_name ResultOverlay
extends Control
## End-of-combat overlay: big title, summary and action buttons, with a
## scale-in entrance. Focus goes to the first button for controller users.

var _title: Label
var _body: Label
var _buttons: HBoxContainer
var _panel: PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(UIStyle.BG_DEEP, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(box)
	_title = Label.new()
	_title.add_theme_font_override("font", UIStyle.display_font())
	_title.add_theme_font_size_override("font_size", UIStyle.SIZE_BANNER)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.outline_label(_title, 10)
	box.add_child(_title)
	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_theme_font_size_override("font_size", UIStyle.SIZE_LARGE)
	box.add_child(_body)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 16)
	box.add_child(_buttons)


## [param actions]: Array of [label: String, callable: Callable]. The first is primary.
func show_result(title: String, color: Color, body: String, actions: Array) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", color)
	_body.text = body
	for child in _buttons.get_children():
		child.queue_free()
	for i in actions.size():
		var button := Button.new()
		button.text = actions[i][0]
		button.custom_minimum_size = Vector2(220, 60)
		if i == 0:
			button.theme_type_variation = &"PrimaryButton"
		button.pressed.connect(actions[i][1])
		_buttons.add_child(button)
	visible = true
	modulate.a = 0.0
	_panel.pivot_offset = _panel.size / 2
	_panel.scale = Vector2(0.8, 0.8)
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, UIStyle.dur(0.25))
	t.tween_property(_panel, "scale", Vector2.ONE, UIStyle.dur(0.35))
	if _buttons.get_child_count() > 0:
		(_buttons.get_child(0) as Button).grab_focus.call_deferred()
