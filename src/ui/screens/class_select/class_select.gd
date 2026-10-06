extends Control
## Class select: the champions (built classes are playable once unlocked;
## the rest are shown as coming), ascension level, optional seed, Embark.

## Built classes in display order.
const CLASS_ORDER: Array[StringName] = [&"pyre_warden", &"moonblade"]

## Display info for classes whose content isn't built yet.
const PLANNED := [
	{"id": &"hollow_scribe", "name": "Hollow Scribe", "title": "Author of Unwritten Endings", "color": Color("#A3283A"),
		"blurb": "Discard and Erase cards for Ink, then rewrite the fight."},
	{"id": &"rootmother", "name": "Rootmother", "title": "The Walking Grove", "color": Color("#4FD1C5"),
		"blurb": "Grow saplings that fight and shield for you. Spread rot spores."},
]

var _selected: StringName = &"pyre_warden"
var _ascension := 0
var _asc_label: Label
var _seed_edit: LineEdit
var _embark: Button
var _panels: Dictionary = {}  # class id -> PanelContainer (playable only)


func _ready() -> void:
	UIBuild.backdrop(self, 0.45)
	var column := UIBuild.center_column(self, 26, 0)
	column.add_child(UIBuild.title("Choose Your Champion", 52))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)

	var panels: Array = []
	for id in CLASS_ORDER:
		var cls := ContentDB.get_character_class(id)
		if cls == null:
			continue
		var unlocked := MetaProgress.is_class_unlocked(id)
		var xp := MetaProgress.get_class_xp(id)
		var level := MetaProgress.level_for_xp(xp)
		var bounds := MetaProgress.level_bounds(xp)
		var level_text := "Level %d (max)" % level if bounds.y < 0 else "Level %d · %d/%d XP" % [level, xp, bounds.y]
		var footer := "%d HP · Starting relic: %s\n%s" % [cls.max_hp, cls.starting_relic.display_name, level_text] if unlocked \
				else "Locked. " + cls.unlock_hint
		var panel := _class_panel(cls.id, cls.display_name, cls.title, cls.accent_color if id == &"moonblade" else cls.secondary_color,
				cls.description, footer, unlocked, unlocked)
		panels.append(panel)
		if unlocked:
			_panels[id] = panel
	for info in PLANNED:
		panels.append(_class_panel(info.id, info.name, info.title, info.color, info.blurb, "Coming in a content update", false, false))
	for p in panels:
		row.add_child(p)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 16)
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(controls)
	var back := UIBuild.button("Back")
	back.pressed.connect(func(): GameManager.go_to_screen(&"main_menu"))
	controls.add_child(back)
	var minus := UIBuild.button("<", false, Vector2(56, 56))
	minus.pressed.connect(_change_ascension.bind(-1))
	controls.add_child(minus)
	_asc_label = UIBuild.label("", &"HeadingLabel")
	_asc_label.custom_minimum_size = Vector2(200, 0)
	_asc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_child(_asc_label)
	var plus := UIBuild.button(">", false, Vector2(56, 56))
	plus.pressed.connect(_change_ascension.bind(1))
	controls.add_child(plus)
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "Seed (optional)"
	_seed_edit.custom_minimum_size = Vector2(220, 56)
	controls.add_child(_seed_edit)
	_embark = UIBuild.button("Embark", true, Vector2(240, 64))
	_embark.pressed.connect(_on_embark)
	controls.add_child(_embark)
	_change_ascension(0)
	UIBuild.stagger_in(panels, 0.08)
	_embark.grab_focus.call_deferred()


func _class_panel(id: StringName, display: String, subtitle: String, color: Color, blurb: String, footer: String,
		playable: bool, built: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 560)
	panel.set_meta("color", color)
	_style_panel(panel, id == _selected)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var art := Control.new()
	art.custom_minimum_size = Vector2(0, 280)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(art)
	art.draw.connect(func():
		art.draw_circle(Vector2(art.size.x / 2, 150), 120, Color(color, 0.18))
		if not playable:
			VectorIcons.draw(art, &"lock", Vector2(art.size.x / 2, 150), 90, Color(1, 1, 1, 0.35)))
	if playable:
		var body := PlaceholderArt.build(id, color)
		body.position = Vector2(160, 270)
		body.scale = Vector2(0.85, 0.85)
		art.add_child(body)
	var name_label := UIBuild.label(display, &"HeadingLabel", 30, color.lightened(0.3) if playable else UIStyle.TEXT_DIM)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var sub := UIBuild.label(subtitle, &"DimLabel")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var text := UIBuild.rich("[center]%s[/center]" % blurb, UIStyle.SIZE_BODY)
	box.add_child(text)
	var foot := UIBuild.label(footer, &"DimLabel")
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(foot)
	if not playable:
		panel.modulate = Color(0.75, 0.75, 0.8)
	else:
		panel.focus_mode = Control.FOCUS_ALL
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.focus_entered.connect(_select.bind(id))
		panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_select(id)
				if event.double_click:
					_on_embark()
			elif event.is_action_pressed("ui_accept"):
				_on_embark())
	panel.mouse_entered.connect(func():
		if not built:
			EventBus.tooltip_requested.emit(panel, display, "Designed and on the roadmap. Its cards and mechanics arrive in a later content update.")
		elif not playable:
			EventBus.tooltip_requested.emit(panel, display, footer))
	panel.mouse_exited.connect(func(): EventBus.tooltip_cleared.emit(panel))
	return panel


func _style_panel(panel: PanelContainer, selected: bool) -> void:
	var color: Color = panel.get_meta("color")
	var style := UIStyle.box(Color(UIStyle.PANEL, 0.92), UIStyle.RADIUS_PANEL, color if selected else UIStyle.OUTLINE, 4 if selected else 2, 18)
	panel.add_theme_stylebox_override("panel", style)


func _select(id: StringName) -> void:
	if _selected == id:
		return
	_selected = id
	for key in _panels:
		_style_panel(_panels[key], key == id)
	AudioManager.play_ui_id(&"ui_click")
	_change_ascension(0)


func _change_ascension(delta: int) -> void:
	var max_asc := MetaProgress.get_max_ascension(_selected)
	_ascension = clampi(_ascension + delta, 0, max_asc)
	_asc_label.text = "Ascension %d" % _ascension if max_asc > 0 else "Ascension locked"


func _on_embark() -> void:
	_embark.disabled = true
	var seed_text := _seed_edit.text.strip_edges()
	var run_seed := -1
	if not seed_text.is_empty():
		run_seed = seed_text.to_int() if seed_text.is_valid_int() else absi(hash(seed_text))
	GameManager.start_new_run(_selected, _ascension, run_seed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameManager.go_to_screen(&"main_menu")
		get_viewport().set_input_as_handled()
