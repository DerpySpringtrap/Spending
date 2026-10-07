extends Node
## The in-run menu: opens with Esc on the map and in combat, pauses solo runs,
## Options opens and closes, Quit to Main Menu keeps the saved run, Abandon
## asks twice. godot --headless --path . res://tests/pause_menu_test.tscn [-- --shots=<dir>]

var _failures: PackedStringArray = []
var _shots := ""


func _ready() -> void:
	if not has_meta("driver"):
		# Run from a node under the root so scene changes don't free the test.
		var driver := Node.new()
		driver.set_script(get_script())
		driver.set_meta("driver", true)
		driver.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child.call_deferred(driver)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
	UIStyle.speed = 30.0
	await get_tree().process_frame
	GameManager.start_new_run(&"pyre_warden", 0, 77)
	await _until_scene("MapScreen")
	_check(not PauseMenu.is_open(), "menu starts closed")
	_press_escape()
	await get_tree().process_frame
	_check(PauseMenu.is_open(), "Esc opens the menu on the map")
	_check(get_tree().paused, "a solo run pauses under the menu")
	await _shot("pause_menu")
	_press(_button("Options"))
	await get_tree().process_frame
	var overlay := _overlay()
	_check(overlay._options.visible, "Options opens")
	await _shot("pause_options")
	overlay._options.close()
	_press(_button("Resume"))
	await get_tree().process_frame
	_check(not PauseMenu.is_open() and not get_tree().paused, "Resume closes and unpauses")

	# In combat: hotkeys are blocked while the menu is open.
	GameManager.start_combat(ContentDB.get_encounter(&"a1_toad_and_beetle"))
	await _until_scene("CombatScreen")
	await get_tree().create_timer(0.5).timeout
	PauseMenu.open()
	await get_tree().process_frame
	_check(PauseMenu.is_open() and get_tree().paused, "the menu opens in combat too")
	var abandon := _button("Abandon Run")
	_press(abandon)
	_check(abandon.text.begins_with("Abandon this run?"), "Abandon asks for confirmation first")
	_check(RunState.active, "one press doesn't abandon")
	_press(_button("Quit to Main Menu"))
	await _until_scene("MainMenu")
	_check(not get_tree().paused, "unpaused after quitting")
	_check(RunState.has_saved_run(), "the run is still saved to continue")
	print("PAUSE MENU TEST: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	for f in _failures:
		print("  FAIL: ", f)
	RunState.clear()
	get_tree().quit(0 if _failures.is_empty() else 1)


func _overlay() -> RunMenuOverlay:
	for child in get_tree().current_scene.get_children():
		if child is RunMenuOverlay:
			return child
	return null


func _button(text: String) -> Button:
	return _find(_overlay(), text)


func _find(node: Node, text: String) -> Button:
	if node == null:
		return null
	for child in node.get_children():
		if child is Button and child.text.begins_with(text):
			return child
		var found := _find(child, text)
		if found:
			return found
	return null


func _press(b: Button) -> void:
	if b == null:
		_failures.append("button missing")
		return
	b.pressed.emit()


func _press_escape() -> void:
	var e := InputEventAction.new()
	e.action = &"ui_cancel"
	e.pressed = true
	Input.parse_input_event(e)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)


func _until_scene(name: String) -> void:
	for i in 600:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene and scene.name == name and not SceneRouter.is_transitioning:
			return
	_failures.append("never reached %s" % name)


func _shot(key: String) -> void:
	if _shots == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shots.path_join(key + ".png"))
