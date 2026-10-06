extends Control
## Temporary entry scene: confirms the autoloads and content registry come up.
## Replaced by the main menu in Milestone 2.

@onready var _status: Label = %Status


func _ready() -> void:
	_status.text = "Autoloads OK\n%d classes · %d cards · %d statuses · %d enemies · %d relics loaded\n\nCombat prototype arrives in Milestone 1." % [
		ContentDB.classes.size(), ContentDB.cards.size(), ContentDB.statuses.size(),
		ContentDB.enemies.size(), ContentDB.relics.size(),
	]
