class_name PileViewer
extends Control
## Full-screen overlay listing a pile's cards (draw, discard, exhaust, deck).
## Scale-in animation; Esc / B / the Close button closes it.

signal closed

const COLUMNS := 6

## Picker mode: "" (view only), "upgrade", "remove" or "choose".
var _mode := ""
var _on_pick: Callable
var _picked := false

var _title: Label
var _grid: GridContainer
var _scroll: ScrollContainer
var _panel: PanelContainer
var _close: Button
var _confirm: Button
## Multi-pick mode ("choose_many"): selected views, limits and callback.
var _selected_views: Array = []
var _min_pick := 0
var _max_pick := 0
var _focus := -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_index = 200  # Above hand cards, which raise their own z_index up to 100.
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
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_title)
	_confirm = Button.new()
	_confirm.theme_type_variation = &"PrimaryButton"
	_confirm.custom_minimum_size = Vector2(220, 0)
	_confirm.visible = false
	_confirm.pressed.connect(_on_confirm)
	header.add_child(_confirm)
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


## Opens as a picker. [param mode]: "upgrade" (hover previews the upgrade),
## "remove" or "choose". [param on_pick] = Callable(card: CardInstance).
func open_picker(title: String, cards: Array, mode: String, on_pick: Callable, cancellable: bool = true) -> void:
	open(title, cards, Callable(), true)
	_mode = mode
	_on_pick = on_pick
	_picked = false
	_close.text = "Cancel (Esc)" if cancellable else ""
	_close.visible = cancellable
	for view in _grid.get_children():
		if view is CardView:
			view.pressed.connect(_on_view_pressed)
			if mode == "upgrade":
				view.hovered.connect(func(v: CardView): _preview_upgrade(v, true))
				view.unhovered.connect(func(v: CardView): _preview_upgrade(v, false))


## Pick between [param min_count] and [param max_count] cards, then Confirm.
## [param on_done] = Callable(chosen: Array[CardInstance]). Can't be cancelled.
func open_multi_picker(title: String, cards: Array, min_count: int, max_count: int, on_done: Callable) -> void:
	open(title, cards, Callable(), true)
	_mode = "choose_many"
	_on_pick = on_done
	_picked = false
	_min_pick = min_count
	_max_pick = max_count
	_selected_views.clear()
	_focus = -1
	_close.visible = false
	_confirm.visible = true
	for view in _grid.get_children():
		if view is CardView:
			view.pressed.connect(func(v: CardView, event: InputEventMouseButton):
				if event.button_index == MOUSE_BUTTON_LEFT:
					_toggle(v))
	_update_confirm()
	_confirm.grab_focus()


func _toggle(view: CardView) -> void:
	if _picked:
		return
	if _selected_views.has(view):
		_selected_views.erase(view)
		view.selected = false
	elif _selected_views.size() < _max_pick:
		_selected_views.append(view)
		view.selected = true
	elif _max_pick == 1 and not _selected_views.is_empty():
		_selected_views[0].selected = false
		_selected_views = [view]
		view.selected = true
	AudioManager.play_ui_id(&"card_hover")
	_update_confirm()


func _update_confirm() -> void:
	var n := _selected_views.size()
	_confirm.disabled = n < _min_pick or n > _max_pick
	_confirm.text = "Confirm (%d/%d)" % [n, _max_pick]


func _on_confirm() -> void:
	if _picked or _confirm.disabled:
		return
	_picked = true
	var chosen: Array = []
	for view in _selected_views:
		chosen.append(view.card)
	var cb := _on_pick
	_mode = ""
	_confirm.visible = false
	close()
	cb.call(chosen)


func _preview_upgrade(view: CardView, on: bool) -> void:
	if _picked:
		return
	var original: CardInstance = view.get_meta("original", view.card)
	view.set_meta("original", original)
	view.setup(CardInstance.new(original.data, true) if on else original)
	view.glowing = on


func _on_view_pressed(view: CardView, event: InputEventMouseButton) -> void:
	if _picked or event.button_index != MOUSE_BUTTON_LEFT:
		return
	_picked = true
	var card: CardInstance = view.get_meta("original", view.card)
	EventBus.tooltip_cleared.emit(view)
	var t := view.create_tween()
	match _mode:
		"upgrade":
			view.setup(CardInstance.new(card.data, true))
			view.play_upgrade_glow()
			t.tween_interval(UIStyle.dur(0.6))
		"remove":
			view.pivot_offset = view.size / 2
			t.set_parallel(true)
			t.tween_property(view, "scale", Vector2(0.6, 0.6), UIStyle.dur(0.35))
			t.tween_property(view, "modulate", Color(1.5, 0.6, 0.6, 0.0), UIStyle.dur(0.35))
			t.chain().tween_interval(UIStyle.dur(0.1))
		_:
			t.tween_interval(UIStyle.dur(0.15))
	t.chain().tween_callback(func():
		_mode = ""
		var cb := _on_pick
		close()
		cb.call(card))


## [param render] = Callable(card: CardInstance) -> String for live text.
func open(title: String, cards: Array, render: Callable = Callable(), sorted: bool = false) -> void:
	_mode = ""
	_close.text = "Close (Esc)"
	_close.visible = true
	_confirm.visible = false
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
	if _mode == "choose_many" and _keyboard_pick(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or (_mode == "" and (event.is_action_pressed("view_draw") or event.is_action_pressed("view_discard") or event.is_action_pressed("view_deck"))):
		if _close.visible:
			close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_scroll.scroll_vertical += 320
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_scroll.scroll_vertical -= 320
		get_viewport().set_input_as_handled()


## Keyboard / gamepad for multi-pick: Left/Right moves, Accept toggles the
## focused card (or confirms when none is focused).
func _keyboard_pick(event: InputEvent) -> bool:
	var views := _grid.get_children().filter(func(c): return c is CardView)
	if views.is_empty():
		return false
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		_focus = wrapi(_focus + (1 if event.is_action_pressed("ui_right") else -1), 0, views.size())
		for i in views.size():
			views[i].modulate = Color(1.15, 1.15, 1.15) if i == _focus else Color.WHITE
		return true
	if event.is_action_pressed("ui_accept") and _focus >= 0 and not _confirm.has_focus():
		_toggle(views[_focus])
		return true
	return false
