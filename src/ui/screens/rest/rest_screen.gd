extends Control
## Rest site: heal 30% of max HP, or upgrade a card. One choice, then onward.

var _choices: HBoxContainer
var _continue: Button
var _picker: PileViewer
var _status: Label
var _fire: Control
var _time := 0.0


func _ready() -> void:
	UIBuild.backdrop(self, 0.55)
	UIBuild.top_bar(self)
	var column := UIBuild.center_column(self, 24)
	column.add_child(UIBuild.title("Rest Site", 56))
	_fire = Control.new()
	_fire.custom_minimum_size = Vector2(300, 220)
	_fire.draw.connect(_draw_fire)
	column.add_child(_fire)
	_choices = HBoxContainer.new()
	_choices.add_theme_constant_override("separation", 40)
	_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_choices)
	var heal := RunLogic.rest_heal_amount()
	var rest := _choice_button("Rest", "Heal %d HP" % mini(heal, RunState.max_hp - RunState.hp), &"heart", UIStyle.HP_BAR)
	rest.pressed.connect(_on_rest)
	_choices.add_child(rest)
	var smith := _choice_button("Smith", "Upgrade a card", &"sword", UIStyle.GOLD)
	smith.pressed.connect(_on_smith)
	smith.disabled = RunState.deck.filter(func(c): return c.can_upgrade()).is_empty()
	_choices.add_child(smith)
	_status = UIBuild.label("", &"HeadingLabel")
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status)
	_continue = UIBuild.button("Continue", true, Vector2(260, 64))
	_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue.visible = false
	_continue.pressed.connect(func():
		_continue.disabled = true
		GameManager.complete_node())
	column.add_child(_continue)
	_picker = PileViewer.new()
	add_child(_picker)
	_picker.closed.connect(func():
		if not _continue.visible:
			_choices.get_child(1).grab_focus())
	rest.grab_focus.call_deferred()


func _choice_button(title: String, subtitle: String, glyph: StringName, color: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(320, 190)
	b.text = "\n\n\n%s\n%s" % [title, subtitle]
	b.add_theme_font_size_override("font_size", UIStyle.SIZE_H2)
	var icon := GlyphIcon.make(glyph, color, 64)
	icon.position = Vector2(128, 22)
	b.add_child(icon)
	return b


func _on_rest() -> void:
	var before := RunState.hp
	RunState.heal(RunLogic.rest_heal_amount())
	_finish("You rest by the fire and recover %d HP." % (RunState.hp - before))


func _on_smith() -> void:
	var options := RunState.deck.filter(func(c): return c.can_upgrade())
	_picker.open_picker("Upgrade a Card", options, "upgrade", func(card: CardInstance):
		RunState.upgrade_card(card)
		_finish("%s upgraded." % card.get_display_name()))


func _finish(text: String) -> void:
	for b in _choices.get_children():
		b.disabled = true
	_status.text = text
	_continue.visible = true
	_continue.grab_focus()


func _process(delta: float) -> void:
	_time += delta
	_fire.queue_redraw()


func _draw_fire() -> void:
	var c := Vector2(_fire.size.x / 2, 140)
	var flicker := sin(_time * 9.0) * 0.06 + sin(_time * 13.0) * 0.04
	_fire.draw_circle(c, 120, Color(1.0, 0.55, 0.2, 0.08 + flicker * 0.3))
	VectorIcons.draw(_fire, &"campfire", c, 160 * (1.0 + flicker), Color("#F07A2A"))
