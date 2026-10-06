extends Control
## Title screen: Continue / New Run / Options / Quit, with the Warden standing
## in the swamp and embers drifting up.

## Full-screen overlay (dim + centred panel), so the panel stays centred at
## any window size.
var _options: Control
var _first_option: Control
var _buttons: VBoxContainer


func _ready() -> void:
	UIBuild.backdrop(self, 0.15)
	_build_hero()
	_build_embers()

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	column.anchor_left = 0.52
	column.anchor_right = 0.92
	column.anchor_top = 0.18
	column.anchor_bottom = 0.92
	column.add_theme_constant_override("separation", 16)
	add_child(column)

	var title := UIBuild.title("DUSKBOUND", 120)
	column.add_child(title)
	var subtitle := UIBuild.label("A roguelike deckbuilder", &"DimLabel", UIStyle.SIZE_H2)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	column.add_child(gap)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 14)
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_buttons)
	var entries: Array = []
	if RunState.has_saved_run():
		var info := _saved_run_info()
		var cont := UIBuild.button("Continue  ·  " + info, true, Vector2(460, 68))
		cont.pressed.connect(GameManager.continue_run)
		entries.append(cont)
	var new_run := UIBuild.button("New Run", not RunState.has_saved_run(), Vector2(460, 68))
	new_run.pressed.connect(func(): GameManager.go_to_screen(&"class_select"))
	entries.append(new_run)
	var options := UIBuild.button("Options", false, Vector2(460, 60))
	options.pressed.connect(_toggle_options)
	entries.append(options)
	var quit := UIBuild.button("Quit", false, Vector2(460, 60))
	quit.pressed.connect(func(): get_tree().quit())
	entries.append(quit)
	for b in entries:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_buttons.add_child(b)
	if RunState.has_saved_run():
		var warn := UIBuild.label("Starting a new run abandons the saved one.", &"DimLabel")
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_buttons.add_child(warn)
	UIBuild.stagger_in([title, subtitle] + entries)
	(entries[0] as Button).grab_focus.call_deferred()

	_build_options()
	var version := UIBuild.label("Early playable build · Act 1 · Pyre Warden", &"DimLabel")
	version.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	version.position = Vector2(24, -40)
	version.anchor_top = 1.0
	version.anchor_bottom = 1.0
	version.offset_top = -40
	version.offset_left = 24
	add_child(version)


func _saved_run_info() -> String:
	var data := SaveIO.read_json(RunState.PATH)
	var cls := ContentDB.get_character_class(StringName(data.get("class_id", "")))
	return "%s, floor %d" % [cls.display_name if cls else "?", int(data.get("floor", 0))]


func _build_hero() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var hero := PlaceholderArt.build(&"pyre_warden", Color("#E8692C"))
	hero.position = Vector2(560, 860)
	hero.scale = Vector2(2.0, 2.0)
	holder.add_child(hero)
	var t := hero.create_tween().set_loops()
	t.tween_property(hero, "position:y", 852.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(hero, "position:y", 860.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _build_embers() -> void:
	var p := GPUParticles2D.new()
	p.amount = 60
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.position = Vector2(960, 1100)
	p.texture = CombatFX._dot()
	var m := ParticleProcessMaterial.new()
	m.particle_flag_disable_z = true
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(1000, 20, 0)
	m.direction = Vector3(0, -1, 0)
	m.spread = 20.0
	m.initial_velocity_min = 40.0
	m.initial_velocity_max = 110.0
	m.gravity = Vector3(8, -6, 0)
	m.scale_min = 0.1
	m.scale_max = 0.35
	m.color = Color(1.0, 0.55, 0.2, 0.8)
	p.process_material = m
	add_child(p)


func _build_options() -> void:
	_options = Control.new()
	_options.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options.visible = false
	add_child(_options)
	var dim := ColorRect.new()
	dim.color = Color(UIStyle.BG_DEEP, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			_toggle_options())
	_options.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_options.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(UIBuild.label("Options", &"HeadingLabel"))
	var fast := CheckButton.new()
	fast.text = "Fast animations"
	fast.button_pressed = Settings.fast_mode
	fast.toggled.connect(func(on): Settings.fast_mode = on)
	box.add_child(fast)
	_first_option = fast
	var numbers := CheckButton.new()
	numbers.text = "Damage numbers"
	numbers.button_pressed = Settings.show_damage_numbers
	numbers.toggled.connect(func(on): Settings.show_damage_numbers = on)
	box.add_child(numbers)
	var full := CheckButton.new()
	full.text = "Fullscreen"
	full.button_pressed = Settings.fullscreen
	full.toggled.connect(func(on):
		Settings.fullscreen = on
		Settings.apply_all())
	box.add_child(full)
	box.add_child(UIBuild.label("Screen shake", &"DimLabel", UIStyle.SIZE_BODY))
	var shake := HSlider.new()
	shake.min_value = 0.0
	shake.max_value = 1.5
	shake.step = 0.1
	shake.value = Settings.screen_shake
	shake.value_changed.connect(func(v): Settings.screen_shake = v)
	box.add_child(shake)
	var close := UIBuild.button("Done", true)
	close.pressed.connect(_toggle_options)
	box.add_child(close)


func _toggle_options() -> void:
	_options.visible = not _options.visible
	if not _options.visible:
		Settings.save_settings()
		(_buttons.get_child(0) as Control).grab_focus()
	else:
		_first_option.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _options.visible and event.is_action_pressed("ui_cancel"):
		_toggle_options()
		get_viewport().set_input_as_handled()
