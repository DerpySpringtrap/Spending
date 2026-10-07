extends Control
## The act map: pick the next room. Scrolls to your position; keyboard and
## gamepad cycle through the reachable rooms.
##
## Co-op: clicking a room casts your vote (you can change it until everyone
## has voted); a party panel shows each player's HP and whether they're still
## busy with the last room. The room is chosen once all votes are in.

const ACT_NAMES := {1: "The Drowned Thicket", 2: "The Gilded Catacombs", 3: "The Shattered Observatory", 4: "The Umbral Core"}

var _scroll: ScrollContainer
var _view: MapView
var _top_bar: TopBar
var _pile_viewer: PileViewer
var _focus_index := 0
var _leaving := false
var _party_box: VBoxContainer
var _status: Label
var _vote_tags: Array = []


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

	if RunState.coop:
		_build_party_panel()
		EventBus.coop_state_changed.connect(_refresh_coop)
		_refresh_coop()
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
	if RunState.coop:
		if GameManager.coop_waiting():
			_flash_tip(_view.buttons[node_id], "Waiting for %s." % " and ".join(GameManager.coop_busy_players()))
			return
		AudioManager.play_ui_id(&"map_select")
		GameManager.coop_vote(node_id)
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


# --- Co-op ------------------------------------------------------------------------

func _build_party_panel() -> void:
	var panel := PanelContainer.new()
	panel.offset_left = 30
	panel.offset_top = 100
	panel.offset_right = 360
	add_child(panel)
	_party_box = VBoxContainer.new()
	_party_box.add_theme_constant_override("separation", 6)
	panel.add_child(_party_box)
	_status = UIBuild.label("", &"", UIStyle.SIZE_BODY, UIStyle.GOLD)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 300


func _refresh_coop() -> void:
	if not is_inside_tree() or not RunState.active:
		return
	for child in _party_box.get_children():
		if child != _status:
			child.queue_free()
	if _status.get_parent() == null:
		_party_box.add_child(_status)
	_party_box.add_child(UIBuild.label("Party", &"HeadingLabel", 22))
	var waiting := GameManager.coop_waiting()
	for s in RunState.seats:
		var cls := ContentDB.get_character_class(s.class_id)
		var state := ""
		if waiting:
			state = "ready" if GameManager.coop_done.has(s.index) else "busy…"
		elif GameManager.coop_votes.has(s.index):
			state = "voted"
		else:
			state = "choosing…"
		var you := " (you)" if s.index == RunState.home_seat else ""
		var text := "%s%s · %s\n%d/%d HP · %s" % [s.player_name, you, cls.display_name if cls else "?", s.hp, s.max_hp, state]
		var label := UIBuild.label(text, &"", UIStyle.SIZE_BODY)
		label.add_theme_color_override("font_color", cls.secondary_color.lerp(Color.WHITE, 0.3) if cls else Color.WHITE)
		_party_box.add_child(label)
	if waiting:
		_status.text = "Waiting for %s to finish…" % " and ".join(GameManager.coop_busy_players())
	else:
		_status.text = "Vote for the next room (%d/%d voted)" % [GameManager.coop_votes.size(), RunState.seats.size()]
	for tag in _vote_tags:
		if is_instance_valid(tag):
			tag.queue_free()
	_vote_tags.clear()
	var per_node := {}
	for seat_index in GameManager.coop_votes:
		var node_id: String = GameManager.coop_votes[seat_index]
		if not _view.buttons.has(node_id):
			continue
		var stack: int = per_node.get(node_id, 0)
		per_node[node_id] = stack + 1
		var s := RunState.seats[seat_index]
		var cls := ContentDB.get_character_class(s.class_id)
		var tag := UIBuild.label(s.player_name, &"", 16)
		tag.add_theme_color_override("font_color", cls.secondary_color.lerp(Color.WHITE, 0.3) if cls else Color.WHITE)
		tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		tag.add_theme_constant_override("outline_size", 6)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var button: Control = _view.buttons[node_id]
		button.add_child(tag)
		tag.position = Vector2(button.size.x + 4, -6 + stack * 18)
		_vote_tags.append(tag)
