extends Node
## End-to-end run through the real screens. Spawns a driver under the scene
## tree root (so it survives scene changes) and opens the main menu.
## godot --headless --path . res://tests/flow_test.tscn [-- --shots=<dir> --nodes=30]

func _ready() -> void:
	var driver := Node.new()
	driver.name = "FlowDriver"
	driver.set_script(load("res://tests/flow_driver.gd"))
	get_tree().root.add_child.call_deferred(driver)
	get_tree().change_scene_to_file.call_deferred("res://src/ui/screens/main_menu/main_menu.tscn")
