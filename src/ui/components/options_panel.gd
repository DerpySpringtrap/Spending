class_name OptionsPanel
extends Control
## Full-screen options overlay (dim + centred panel), shared by the main menu
## and the in-run menu. Settings save when it closes.
##
## Volume sliders are hidden while the game has no audio (see SoundBank);
## they come back once SoundBank lists sounds.

signal closed

var _first: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # Usable while the run is paused.
	var dim := ColorRect.new()
	dim.color = Color(UIStyle.BG_DEEP, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			close())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
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
	_first = fast
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
	if not (SoundBank.SFX.is_empty() and SoundBank.MUSIC.is_empty() and SoundBank.AMBIENCE.is_empty()):
		var volumes := GridContainer.new()
		volumes.columns = 2
		volumes.add_theme_constant_override("h_separation", 16)
		box.add_child(volumes)
		for bus in Settings.AUDIO_BUSES:
			volumes.add_child(UIBuild.label("%s volume" % bus, &"DimLabel", UIStyle.SIZE_BODY))
			var slider := HSlider.new()
			slider.min_value = 0.0
			slider.max_value = 1.0
			slider.step = 0.05
			slider.custom_minimum_size = Vector2(260, 24)
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.value = Settings.volumes.get(bus, 1.0)
			slider.value_changed.connect(func(v: float): Settings.set_volume(bus, v))
			volumes.add_child(slider)
	box.add_child(UIBuild.label("Screen shake", &"DimLabel", UIStyle.SIZE_BODY))
	var shake := HSlider.new()
	shake.min_value = 0.0
	shake.max_value = 1.5
	shake.step = 0.1
	shake.value = Settings.screen_shake
	shake.value_changed.connect(func(v): Settings.screen_shake = v)
	box.add_child(shake)
	var done := UIBuild.button("Done", true)
	done.pressed.connect(close)
	box.add_child(done)


func open() -> void:
	visible = true
	_first.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	Settings.save_settings()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
