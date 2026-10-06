extends Control
## Temporary entry scene: confirms the autoloads and content registry come up
## and offers a shortcut into the combat prototype. Replaced by the main menu
## in Milestone 2.

@onready var _status: Label = %Status
@onready var _center: VBoxContainer = $Center


func _ready() -> void:
	_status.text = "%d classes · %d cards · %d statuses · %d enemies · %d relics loaded" % [
		ContentDB.classes.size(), ContentDB.cards.size(), ContentDB.statuses.size(),
		ContentDB.enemies.size(), ContentDB.relics.size(),
	]
	var start := Button.new()
	start.text = "Start Test Combat (Pyre Warden)"
	start.custom_minimum_size = Vector2(420, 64)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.add_theme_font_size_override("font_size", 24)
	start.pressed.connect(func(): GameManager.start_debug_combat())
	start.disabled = ContentDB.get_character_class(&"pyre_warden") == null
	_center.add_child(start)
	var hint := Label.new()
	hint.text = "Drag cards to play · ←/→ + Enter (or gamepad) · E end turn · Q/W piles · A auto-play"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.5)
	_center.add_child(hint)
	start.grab_focus()
