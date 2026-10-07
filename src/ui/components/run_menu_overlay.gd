class_name RunMenuOverlay
extends CanvasLayer
## The in-run menu: Resume, Options, Quit to Main Menu, Abandon Run, Quit Game.
## Solo runs pause underneath; in co-op the game keeps going for the others
## and leaving ends the run for everyone. Risky choices ask twice.

const CONFIRM_TIME := 3.0

var _box: VBoxContainer
var _options: OptionsPanel
var _paused_here := false
var _armed: Button
var _armed_text := ""


func _ready() -> void:
	layer = 90  # Below SceneRouter's fade (100).
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not RunState.coop:
		get_tree().paused = true
		_paused_here = true
	var dim := ColorRect.new()
	dim.color = Color(UIStyle.BG_DEEP, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	panel.add_child(_box)
	var title := UIBuild.title("Menu" if RunState.coop else "Paused", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	if RunState.coop:
		_note("The run keeps going for your friends while this menu is open.")
	var resume := _button("Resume", true, close)
	_button("Options", false, func():
		_options.open())
	if RunState.coop:
		_button("Leave Co-op Run", false, _leave_coop, "Leave? The run ends for everyone. Press again")
		_button("Quit Game", false, func():
			Coop.leave()
			get_tree().quit(), "Quit? The run ends for everyone. Press again")
	else:
		_button("Quit to Main Menu", false, _quit_to_menu)
		_note("Your run is saved from the last time you were on the map; continue it from the main menu.")
		_button("Abandon Run", false, func():
			_unpause()
			queue_free()
			GameManager.abandon_run(), "Abandon this run? Press again")
		_button("Quit Game", false, func(): get_tree().quit())
	_options = OptionsPanel.new()
	_options.closed.connect(func(): resume.grab_focus())
	add_child(_options)
	resume.grab_focus.call_deferred()


func close() -> void:
	_unpause()
	queue_free()


func _exit_tree() -> void:
	_unpause()


func _unpause() -> void:
	if _paused_here:
		get_tree().paused = false
		_paused_here = false


func _quit_to_menu() -> void:
	_unpause()
	queue_free()
	GameManager.go_to_screen(&"main_menu")


func _leave_coop() -> void:
	_unpause()
	queue_free()
	GameManager.abandon_run()


## A menu button; with [param confirm] it must be pressed twice within a few seconds.
func _button(text: String, primary: bool, action: Callable, confirm: String = "") -> Button:
	var b := UIBuild.button(text, primary, Vector2(440, 60))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		if confirm == "" or _armed == b:
			action.call()
			return
		_disarm()
		_armed = b
		_armed_text = text
		b.text = confirm
		get_tree().create_timer(CONFIRM_TIME, true).timeout.connect(func():
			if _armed == b:
				_disarm()))
	_box.add_child(b)
	return b


func _disarm() -> void:
	if is_instance_valid(_armed):
		_armed.text = _armed_text
	_armed = null


func _note(text: String) -> void:
	var label := UIBuild.label(text, &"DimLabel", UIStyle.SIZE_BODY)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size.x = 480
	_box.add_child(label)


## While open, the screen underneath gets no keys (hotkeys like E end turn).
func _unhandled_input(event: InputEvent) -> void:
	if _options.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()
