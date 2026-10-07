extends Node
## Opens the in-run menu (autoload: PauseMenu): Esc on any run screen, or the
## Menu button in the top bar. Screens get first refusal on Esc (closing a
## pile viewer, cancelling a target), so the menu only opens when nothing
## else wanted it.

const RUN_SCREENS: Array[StringName] = [&"MapScreen", &"CombatScreen", &"RewardScreen", &"ShopScreen", &"RestScreen", &"EventScreen"]

var _overlay: RunMenuOverlay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_open() -> bool:
	return is_instance_valid(_overlay) and _overlay.is_inside_tree()


## True on screens where the menu is available.
func can_open() -> bool:
	var scene := get_tree().current_scene
	return RunState.active and scene != null and RUN_SCREENS.has(StringName(scene.name)) and not SceneRouter.is_transitioning


func open() -> void:
	if is_open() or not can_open():
		return
	_overlay = RunMenuOverlay.new()
	# A child of the screen (last), so it sees input before the screen does and
	# goes away with it if the party moves on (co-op).
	get_tree().current_scene.add_child(_overlay)


func close() -> void:
	if is_open():
		_overlay.close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not is_open() and can_open():
		open()
		get_viewport().set_input_as_handled()
