class_name PileViewer
extends Control
## Full-screen overlay listing a pile's cards (draw, discard, exhaust, deck).
## Scale-in animation; Esc / B / the Close button closes it.

signal closed

const COLUMNS := 6

var _title: Label
var _grid: GridContainer
var _scroll: ScrollContainer
var _panel: PanelContainer
var _close: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(UIStyle.BG_DEEP, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(1400, 860)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	_title = Label.new()
	_title.theme_type_variation = &"TitleLabel"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_close = Button.new()
	_close.text = "Close (Esc)"
	_close.pressed.connect(close)
	header.add_child(_close)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_scroll.add_child(margin)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 22)
	_grid.add_theme_constant_override("v_separation", 22)
	margin.add_child(_grid)


## [param render] = Callable(card: CardInstance) -> String for live text.
func open(title: String, cards: Array, render: Callable = Callable(), sorted: bool = false) -> void:
	for child in _grid.get_children():
		child.queue_free()
	var list := cards.duplicate()
	if sorted:
		list.sort_custom(func(a, b):
			if a.data.rarity != b.data.rarity:
				return a.data.rarity > b.data.rarity
			return a.data.display_name < b.data.display_name)
	_title.text = "%s (%d)" % [title, list.size()]
	for card in list:
		var view := CardView.new().setup(card)
		view.mouse_filter = Control.MOUSE_FILTER_PASS
		_grid.add_child(view)
		if render.is_valid():
			view.set_description(render.call(card))
		view.hovered.connect(func(v): EventBus.tooltip_requested.emit(v, "", CardTooltips.for_card(v.card)))
		view.unhovered.connect(func(v): EventBus.tooltip_cleared.emit(v))
	if list.is_empty():
		var empty := Label.new()
		empty.text = "No cards."
		empty.theme_type_variation = &"DimLabel"
		_grid.add_child(empty)
	_scroll.scroll_vertical = 0
	visible = true
	modulate.a = 0.0
	_panel.pivot_offset = _panel.size / 2
	_panel.scale = Vector2(0.92, 0.92)
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, UIStyle.dur(0.18))
	t.tween_property(_panel, "scale", Vector2.ONE, UIStyle.dur(0.22))
	_close.grab_focus()


func close() -> void:
	if not visible:
		return
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, UIStyle.dur(0.12))
	t.tween_callback(func():
		visible = false
		closed.emit())


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("view_draw") or event.is_action_pressed("view_discard"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_scroll.scroll_vertical += 320
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_scroll.scroll_vertical -= 320
		get_viewport().set_input_as_handled()
