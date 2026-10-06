extends Control
## The act map: pick the next room. Scrolls to your position; keyboard and
## gamepad cycle through the reachable rooms.

const ACT_NAMES := {1: "The Drowned Thicket", 2: "The Gilded Catacombs"}

var _scroll: ScrollContainer
var _view: MapView
var _top_bar: TopBar
var _pile_viewer: PileViewer
var _focus_index := 0
var _leaving := false


func _ready() -> void:
	UIBuild.backdrop(self, 0.55)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_top = 64
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(center)
	_view = MapView.new()
	center.add_child(_view)
	_view.build(RunState.map_data, RunState.current_node, RunState.visited_nodes)
	_view.node_chosen.connect(_on_node_chosen)

	_build_legend()
	_top_bar = UIBuild.top_bar(self)
	_top_bar.potion_activated.connect(_on_potion)
	_top_bar.potion_discard_requested.connect(_on_potion_discard)
	_top_bar.deck_pressed.connect(_show_deck)
	_pile_viewer = PileViewer.new()
	add_child(_pile_viewer)

	_scroll_to_current.call_deferred()
	if RunState.current_node == "":
		_show_act_title()
	var reachable := _view.reachable_buttons()
	if not reachable.is_empty():
		(reachable[0] as Control).grab_focus.call_deferred()


func _scroll_to_current() -> void:
	await get_tree().process_frame
	var f := 0 if RunState.current_node == "" else int(RunState.map_data.nodes[RunState.current_node].floor) + 1
	var target := clampf(_view.floor_y(f) - _scroll.size.y * 0.62, 0, _view.size.y)
	var start := clampf(target + 260, 0, _view.size.y)
	_scroll.scroll_vertical = int(start)
	create_tween().tween_property(_scroll, "scroll_vertical", int(target), UIStyle.dur(0.8)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _show_act_title() -> void:
	var label := UIBuild.title("Act %d\n%s" % [RunState.act, ACT_NAMES.get(RunState.act, "")], 64)
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 0.35
	label.anchor_bottom = 0.35
	add_child(label)
	label.modulate.a = 0.0
	var t := label.create_tween()
	t.tween_property(label, "modulate:a", 1.0, UIStyle.dur(0.6))
	t.tween_interval(UIStyle.dur(1.4))
	t.tween_property(label, "modulate:a", 0.0, UIStyle.dur(0.8))
	t.tween_callback(label.queue_free)


func _build_legend() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.anchor_left = 1.0
	panel.offset_left = -270
	panel.offset_top = 100
	panel.offset_right = -30
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(UIBuild.label("Legend", &"HeadingLabel", 22))
	for type in ["monster", "elite", "rest", "shop", "treasure", "event", "boss"]:
		var info: Dictionary = MapNodeButton.INFO[type]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(GlyphIcon.make(info.glyph, info.color, 28))
		row.add_child(UIBuild.label(info.name, &"", UIStyle.SIZE_BODY))
		box.add_child(row)
	var hint := UIBuild.label("←/→ choose · Enter travel\nD deck · scroll to look ahead", &"DimLabel")
	box.add_child(hint)


func _on_node_chosen(node_id: String) -> void:
	if _leaving or _pile_viewer.visible:
		return
	_leaving = true
	AudioManager.play_ui_id(&"map_select")
	var b: MapNodeButton = _view.buttons[node_id]
	var t := b.create_tween()
	t.tween_property(b, "scale", Vector2(1.35, 1.35), UIStyle.dur(0.12)).set_trans(Tween.TRANS_BACK)
	t.tween_property(b, "scale", Vector2.ONE, UIStyle.dur(0.12))
	t.tween_callback(func(): GameManager.select_map_node(node_id))


func _show_deck() -> void:
	_pile_viewer.open("Your Deck", RunState.deck, Callable(), true)


func _on_potion(slot: int) -> void:
	var potion: PotionData = RunState.potions[slot]
	if potion == null:
		return
	if not potion.usable_outside_combat:
		_flash_tip(_top_bar.potion_icon(slot), "Use this potion in combat.")
		return
	for effect in potion.effects:
		if effect is HealEffect:
			RunState.heal(effect.amount)
	AudioManager.play(&"potion")
	RunState.remove_potion(slot)
	EventBus.potion_used.emit(potion, slot)
	_top_bar.refresh()


func _on_potion_discard(slot: int) -> void:
	var potion: PotionData = RunState.remove_potion(slot)
	EventBus.potion_discarded.emit(potion, slot)
	_top_bar.refresh()


func _flash_tip(owner: Control, text: String) -> void:
	EventBus.tooltip_requested.emit(owner, "", text)


func _unhandled_input(event: InputEvent) -> void:
	if _pile_viewer.visible or _leaving:
		return
	var reachable := _view.reachable_buttons()
	if event.is_action_pressed("view_deck"):
		_show_deck()
	elif not reachable.is_empty() and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		_focus_index = wrapi(_focus_index + (1 if event.is_action_pressed("ui_right") else -1), 0, reachable.size())
		(reachable[_focus_index] as Control).grab_focus()
	else:
		return
	get_viewport().set_input_as_handled()
