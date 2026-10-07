extends Control
## Post-fight / treasure rewards: click each reward to take it, pick one of
## three cards (or skip), then Proceed.

var _rows: VBoxContainer
var _proceed: Button
var _top_bar: TopBar
var _card_overlay: Control
var _message: Label


func _ready() -> void:
	UIBuild.backdrop(self, 0.6)
	_top_bar = UIBuild.top_bar(self)
	var column := UIBuild.center_column(self, 18)
	var title := UIBuild.title(GameManager.reward_title, 56)
	column.add_child(title)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	column.add_child(panel)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 10)
	panel.add_child(_rows)
	for reward in GameManager.pending_rewards:
		_rows.add_child(_reward_row(reward))
	_message = UIBuild.label("", &"", UIStyle.SIZE_LARGE, UIStyle.DEBUFFED)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_message)
	_proceed = UIBuild.button("Proceed", true, Vector2(280, 64))
	_proceed.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_proceed.pressed.connect(_on_proceed)
	column.add_child(_proceed)
	UIBuild.stagger_in([title, panel, _proceed])
	_focus_first()


func _reward_row(reward: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(580, 70)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBox = b.get_theme_stylebox(state).duplicate()
		sb.content_margin_left = 68
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_font_size_override("font_size", UIStyle.SIZE_LARGE)
	b.set_meta("reward", reward)
	var glyph := &"star"
	var color := UIStyle.GOLD
	match String(reward.type):
		"gold":
			b.text = "%d Gold" % reward.amount
			glyph = &"coin"
		"card":
			b.text = "Add a card to your deck"
			glyph = &"cards"
			color = UIStyle.TEXT
		"relic":
			b.text = "Relic: %s" % reward.relic.display_name
			glyph = &"sun"
			b.mouse_entered.connect(func(): EventBus.tooltip_requested.emit(b, reward.relic.display_name, reward.relic.description))
			b.mouse_exited.connect(func(): EventBus.tooltip_cleared.emit(b))
		"relic_choice":
			b.text = "Choose a boss relic"
			glyph = &"crown"
		"potion":
			b.text = "Potion: %s" % reward.potion.display_name
			glyph = &"drop"
			color = reward.potion.liquid_color
			b.mouse_entered.connect(func(): EventBus.tooltip_requested.emit(b, reward.potion.display_name, reward.potion.description))
			b.mouse_exited.connect(func(): EventBus.tooltip_cleared.emit(b))
	var icon := GlyphIcon.make(glyph, color, 36)
	icon.position = Vector2(14, 17)
	b.add_child(icon)
	b.pressed.connect(_claim.bind(b))
	return b


func _claim(row: Button) -> void:
	var reward: Dictionary = row.get_meta("reward")
	match String(reward.type):
		"gold":
			RunState.add_gold(reward.amount)
			AudioManager.play(&"gold")
		"relic":
			RunState.add_relic(reward.relic)
			AudioManager.play(&"relic", 0.0)
		"potion":
			if RunState.add_potion(reward.potion) < 0:
				_show_message("Your potion slots are full. Discard one from the top bar first.")
				return
			AudioManager.play(&"potion")
		"card":
			_open_card_choice(row, reward.choices, reward.get("upgraded", []))
			return
		"relic_choice":
			_open_relic_choice(row, reward.choices)
			return
	_remove_row(row)


func _remove_row(row: Button) -> void:
	EventBus.tooltip_cleared.emit(row)
	row.disabled = true
	var t := row.create_tween()
	t.tween_property(row, "modulate:a", 0.0, UIStyle.dur(0.2))
	t.tween_callback(func():
		row.queue_free()
		_focus_first.call_deferred())
	_top_bar.refresh()


func _focus_first() -> void:
	for child in _rows.get_children():
		if child is Button and not child.disabled and not child.is_queued_for_deletion():
			child.grab_focus()
			return
	_proceed.text = "Proceed"
	_proceed.grab_focus()


func _show_message(text: String) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	var t := _message.create_tween()
	t.tween_interval(1.8)
	t.tween_property(_message, "modulate:a", 0.0, 0.5)


func _on_proceed() -> void:
	_proceed.disabled = true
	GameManager.complete_node()


# --- Card choice ------------------------------------------------------------------

func _open_card_choice(row: Button, choices: Array, upgraded: Array = []) -> void:
	_card_overlay = Control.new()
	_card_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_card_overlay)
	var dim := ColorRect.new()
	dim.color = Color(UIStyle.BG_DEEP, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_overlay.add_child(dim)
	var column := UIBuild.center_column(_card_overlay, 40, 0)
	column.add_child(UIBuild.title("Choose a Card", 48))
	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 60)
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(cards_row)
	var views: Array = []
	for i in choices.size():
		var data: CardData = choices[i]
		var is_upgraded: bool = i < upgraded.size() and upgraded[i]
		var holder := Control.new()
		holder.custom_minimum_size = CardView.SIZE * 1.3
		cards_row.add_child(holder)
		var view := CardView.new().setup(CardInstance.new(data, is_upgraded))
		view.pivot_offset = CardView.SIZE / 2
		view.scale = Vector2(1.3, 1.3)
		view.position = (holder.custom_minimum_size - CardView.SIZE) / 2
		holder.add_child(view)
		views.append(view)
		view.hovered.connect(func(v):
			EventBus.tooltip_requested.emit(v, "", CardTooltips.for_card(v.card))
			v.create_tween().tween_property(v, "scale", Vector2(1.42, 1.42), UIStyle.dur(0.12)))
		view.unhovered.connect(func(v):
			EventBus.tooltip_cleared.emit(v)
			v.create_tween().tween_property(v, "scale", Vector2(1.3, 1.3), UIStyle.dur(0.12)))
		view.pressed.connect(func(v, event):
			if event.button_index == MOUSE_BUTTON_LEFT:
				_pick_card(row, v))
	var skip := UIBuild.button("Skip", false, Vector2(220, 56))
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip.pressed.connect(func(): _close_card_choice())
	column.add_child(skip)
	_card_overlay.set_meta("views", views)
	_card_overlay.set_meta("focus", -1)
	UIBuild.stagger_in(views, 0.08)
	skip.grab_focus()


func _pick_card(row: Button, view: CardView) -> void:
	if _card_overlay == null or _card_overlay.has_meta("picked"):
		return
	_card_overlay.set_meta("picked", true)
	EventBus.tooltip_cleared.emit(view)
	RunState.add_card(view.card.data, view.card.upgraded)
	AudioManager.play(&"card_create")
	view.glowing = true
	var t := view.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(view, "global_position", Vector2(get_viewport_rect().size.x - 180, 10), UIStyle.dur(0.4)).set_delay(UIStyle.dur(0.15))
	t.tween_property(view, "scale", Vector2(0.15, 0.15), UIStyle.dur(0.4)).set_delay(UIStyle.dur(0.15))
	t.chain().tween_callback(func():
		_close_card_choice()
		_remove_row(row))


# --- Boss relic choice -------------------------------------------------------------

func _open_relic_choice(row: Button, choices: Array) -> void:
	_card_overlay = Control.new()
	_card_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_card_overlay)
	var dim := ColorRect.new()
	dim.color = Color(UIStyle.BG_DEEP, 0.95)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_overlay.add_child(dim)
	var column := UIBuild.center_column(_card_overlay, 30, 0)
	column.add_child(UIBuild.title("Choose a Boss Relic", 48))
	var row_box := HBoxContainer.new()
	row_box.add_theme_constant_override("separation", 30)
	row_box.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row_box)
	var buttons: Array = []
	for relic: RelicData in choices:
		var b := Button.new()
		b.custom_minimum_size = Vector2(320, 300)
		b.set_meta("relic", relic)
		var box := VBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 20
		box.offset_right = -20
		box.offset_top = 24
		box.offset_bottom = -20
		box.add_theme_constant_override("separation", 12)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(box)
		var icon_holder := CenterContainer.new()
		icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon_holder)
		var icon := RelicIcon.new()
		icon.relic = relic
		icon.scale = Vector2(1.6, 1.6)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_holder.add_child(icon)
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 26)
		box.add_child(spacer)
		var name_label := UIBuild.label(relic.display_name, &"HeadingLabel", 26, UIStyle.GOLD)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name_label)
		var desc := UIBuild.rich("[center]%s[/center]" % relic.description, UIStyle.SIZE_BODY)
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(desc)
		b.pressed.connect(_pick_relic.bind(row, b))
		row_box.add_child(b)
		buttons.append(b)
	var skip := UIBuild.button("Skip", false, Vector2(220, 56))
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip.pressed.connect(func(): _close_card_choice())
	column.add_child(skip)
	_card_overlay.set_meta("relic_buttons", buttons)
	UIBuild.stagger_in(buttons, 0.08)
	if buttons.is_empty():
		skip.grab_focus()
	else:
		(buttons[0] as Control).grab_focus()


func _pick_relic(row: Button, button: Button) -> void:
	if _card_overlay == null or _card_overlay.has_meta("picked"):
		return
	_card_overlay.set_meta("picked", true)
	var relic: RelicData = button.get_meta("relic")
	RunState.add_relic(relic)
	AudioManager.play(&"relic", 0.0)
	_top_bar.refresh()
	var t := button.create_tween()
	t.tween_property(button, "modulate", Color(1.6, 1.4, 0.8), UIStyle.dur(0.15))
	t.tween_interval(UIStyle.dur(0.25))
	t.tween_callback(func():
		_close_card_choice()
		_remove_row(row))


func _close_card_choice() -> void:
	if _card_overlay:
		_card_overlay.queue_free()
		_card_overlay = null
	_focus_first.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if _card_overlay == null:
		return
	if not _card_overlay.has_meta("views"):
		if event.is_action_pressed("ui_cancel"):
			_close_card_choice()
			get_viewport().set_input_as_handled()
		return
	var views: Array = _card_overlay.get_meta("views")
	var focus: int = _card_overlay.get_meta("focus")
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		focus = wrapi(focus + (1 if event.is_action_pressed("ui_right") else -1), 0, views.size())
		for i in views.size():
			views[i].selected = i == focus
		_card_overlay.set_meta("focus", focus)
	elif event.is_action_pressed("ui_accept") and focus >= 0:
		var rows := _rows.get_children().filter(func(r): return r is Button and String(r.get_meta("reward").type) == "card" and not r.disabled)
		if not rows.is_empty():
			_pick_card(rows[0], views[focus])
	elif event.is_action_pressed("ui_cancel"):
		_close_card_choice()
	else:
		return
	get_viewport().set_input_as_handled()
