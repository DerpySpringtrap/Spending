extends Control
## "?" event: art, story text and choices. Outcomes apply through RunLogic;
## card picks and fights are handed off, then the result text is shown.

var _event: EventData
var _text: RichTextLabel
var _choices: VBoxContainer
var _top_bar: TopBar
var _picker: PileViewer
var _art: Control
var _time := 0.0
var _pending_outcomes: Array = []
var _result_text := ""


func _ready() -> void:
	_event = GameManager.pending_event
	UIBuild.backdrop(self, 0.6)
	_top_bar = UIBuild.top_bar(self)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 64
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1300, 640)
	center.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	panel.add_child(row)
	_art = Control.new()
	_art.custom_minimum_size = Vector2(440, 600)
	_art.draw.connect(_draw_art)
	row.add_child(_art)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 22)
	row.add_child(column)
	var title := UIBuild.label(_event.title, &"TitleLabel", 44)
	column.add_child(title)
	_text = UIBuild.rich(_event.description, UIStyle.SIZE_H2 - 4)
	_text.custom_minimum_size = Vector2(760, 0)
	column.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 12)
	column.add_child(_choices)
	for c in _event.choices:
		var b := UIBuild.button(c.text, false, Vector2(760, 62))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var reason := RunLogic.choice_available(c)
		if reason != "":
			b.disabled = true
			b.text += "   (%s)" % reason
		b.pressed.connect(_choose.bind(c))
		_choices.add_child(b)
	_picker = PileViewer.new()
	add_child(_picker)
	UIBuild.stagger_in([title, _text, _choices])
	for b in _choices.get_children():
		if not b.disabled:
			b.grab_focus.call_deferred()
			break


func _choose(choice: EventChoice) -> void:
	for b in _choices.get_children():
		b.disabled = true
	_result_text = choice.result_text
	_pending_outcomes = choice.outcomes.duplicate()
	_apply_next()


## Applies outcomes in order, pausing for card picks; a fight ends the screen.
func _apply_next() -> void:
	while not _pending_outcomes.is_empty():
		var outcome: EventOutcome = _pending_outcomes.pop_front()
		match RunLogic.apply_outcome(outcome):
			"remove":
				_picker.open_picker("Remove a Card", RunState.deck, "remove", func(card):
					RunState.remove_card(card)
					_apply_next(), false)
				return
			"upgrade":
				var options := RunState.deck.filter(func(c): return c.can_upgrade())
				if not options.is_empty():
					_picker.open_picker("Upgrade a Card", options, "upgrade", func(card):
						RunState.upgrade_card(card)
						_apply_next(), false)
					return
			"fight":
				GameManager.start_combat(outcome.encounter, true)
				return
	_top_bar.refresh()
	_show_result()


func _show_result() -> void:
	_text.text = _result_text if not _result_text.is_empty() else "You move on."
	for b in _choices.get_children():
		b.queue_free()
	var cont := UIBuild.button("Continue", true, Vector2(260, 60))
	cont.pressed.connect(func():
		cont.disabled = true
		GameManager.complete_node())
	_choices.add_child(cont)
	cont.grab_focus()


func _process(delta: float) -> void:
	_time += delta
	_art.queue_redraw()


func _draw_art() -> void:
	var c := Vector2(_art.size.x / 2, _art.size.y / 2)
	_art.draw_style_box(UIStyle.box(Color(UIStyle.BG_DEEP, 0.7), UIStyle.RADIUS_PANEL, UIStyle.GOLD.darkened(0.5), 2), Rect2(Vector2.ZERO, _art.size))
	for i in 3:
		var r := 120.0 + i * 50.0 + sin(_time * 1.5 + i) * 6.0
		_art.draw_arc(c, r, 0, TAU, 64, Color(UIStyle.GOLD, 0.08 + 0.03 * (2 - i)), 2.0)
	_art.draw_circle(c, 110, Color(UIStyle.GOLD, 0.06))
	VectorIcons.draw(_art, _event.glyph, c + Vector2(0, sin(_time * 2.0) * 6.0), 150, UIStyle.GOLD.lightened(0.1))
