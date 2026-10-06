@tool
extends EditorScript
## Regenerates src/ui/theme/main_theme.tres from the tokens in UIStyle.
## Run from the Script editor: File → Run (Ctrl+Shift+X) after editing UIStyle.

const PATH := "res://src/ui/theme/main_theme.tres"


func _run() -> void:
	var err := ResourceSaver.save(UIStyle.build_theme(), PATH)
	print("Theme saved to %s: %s" % [PATH, error_string(err)])
