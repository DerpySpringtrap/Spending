extends Node
## Two-player co-op run through the real screens over a real network
## connection (localhost). Run two copies at once:
##   godot --headless --path . res://tests/coop_test.tscn -- --role=host --class=pyre_warden
##   godot --headless --path . res://tests/coop_test.tscn -- --role=client --class=rootmother
## Each prints "COOP SYNC <floor>: <state>" lines at every vote; the two
## outputs must match (tools/coop_test.sh compares them).

func _ready() -> void:
	var driver := Node.new()
	driver.name = "CoopDriver"
	driver.set_script(load("res://tests/coop_driver.gd"))
	get_tree().root.add_child.call_deferred(driver)
	get_tree().change_scene_to_file.call_deferred("res://src/ui/screens/main_menu/main_menu.tscn")
