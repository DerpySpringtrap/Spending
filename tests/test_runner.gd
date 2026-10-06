extends Node
## Runs every tests/unit/test_*.gd. Exit code 0 = all passed.
## godot --headless --path . res://tests/test_runner.tscn

const UNIT_DIR := "res://tests/unit"


func _ready() -> void:
	var total := 0
	var failed: PackedStringArray = []
	for file in DirAccess.get_files_at(UNIT_DIR):
		file = file.trim_suffix(".remap")
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: GDScript = load(UNIT_DIR.path_join(file))
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			var test: TestCase = script.new()
			test._current_test = "%s::%s" % [file.get_basename(), name]
			test.before_each()
			test.call(name)
			total += 1
			if test.failures.is_empty():
				print("  ok    ", test._current_test)
			else:
				print("  FAIL  ", test._current_test)
				for f in test.failures:
					print("        ", f)
				failed.append_array(test.failures)
	print("\n%d tests, %d failures" % [total, failed.size()])
	print("TESTS: %s" % ("PASS" if failed.is_empty() else "FAIL"))
	get_tree().quit(1 if not failed.is_empty() else 0)
