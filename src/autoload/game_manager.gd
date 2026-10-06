extends Node
## High-level game flow (autoload: GameManager).
##
## The only place that decides "what screen comes next". Screens call these
## methods instead of changing scenes themselves, which keeps flow logic in one
## place and makes it easy to insert things later (tutorial popups, unlock
## screens, the boss intro).

const MAX_ASCENSION := 15

## Screen scene paths. Screens that don't exist yet fall back to the boot scene.
const SCREENS := {
	&"boot": "res://src/boot/boot.tscn",
	&"main_menu": "res://src/ui/screens/main_menu/main_menu.tscn",
	&"class_select": "res://src/ui/screens/class_select/class_select.tscn",
	&"map": "res://src/map/map_screen.tscn",
	&"combat": "res://src/combat/combat_screen.tscn",
	&"reward": "res://src/ui/screens/reward/reward_screen.tscn",
	&"shop": "res://src/ui/screens/shop/shop_screen.tscn",
	&"rest": "res://src/ui/screens/rest/rest_screen.tscn",
	&"event": "res://src/ui/screens/event/event_screen.tscn",
	&"run_summary": "res://src/ui/screens/run_summary/run_summary.tscn",
}

## Set before switching to the combat screen; read by it on _ready.
var pending_encounter: EncounterData
## Snapshot taken in end_run() for the run-summary screen, since RunState is
## cleared before that screen loads.
var last_run_summary: Dictionary = {}


func go_to_screen(screen_id: StringName) -> void:
	var path: String = SCREENS.get(screen_id, SCREENS[&"boot"])
	if not ResourceLoader.exists(path):
		push_warning("GameManager: screen '%s' not built yet (%s)" % [screen_id, path])
		path = SCREENS[&"boot"]
	SceneRouter.go_to(path, screen_id)


func start_new_run(class_id: StringName, ascension: int = 0, run_seed: int = -1) -> void:
	var class_data := ContentDB.get_character_class(class_id)
	if class_data == null:
		push_error("GameManager: unknown class %s" % class_id)
		return
	if run_seed < 0:
		run_seed = randi()
	RunState.start(class_data, clampi(ascension, 0, MAX_ASCENSION), run_seed)
	MetaProgress.stats["runs_started"] += 1
	MetaProgress.save_meta()
	EventBus.run_started.emit(class_id, ascension, run_seed)
	RunState.save_run()
	go_to_screen(&"map")


func continue_run() -> void:
	if RunState.load_run():
		go_to_screen(&"map")
	else:
		push_warning("GameManager: saved run is missing or invalid; discarding it")
		RunState.clear()
		go_to_screen(&"main_menu")


func start_combat(encounter: EncounterData) -> void:
	pending_encounter = encounter
	go_to_screen(&"combat")


## Called when the player dies, wins the final boss, or abandons the run.
func end_run(victory: bool) -> void:
	var xp := RunState.floor_number * 5 + (100 if victory else 0) + RunState.ascension * 10
	MetaProgress.record_run(RunState.class_id, victory, RunState.floor_number, RunState.ascension, xp)
	last_run_summary = {
		"victory": victory, "class_id": RunState.class_id, "ascension": RunState.ascension,
		"act": RunState.act, "floor": RunState.floor_number, "xp": xp,
		"deck": RunState.deck.duplicate(), "relics": RunState.relics.duplicate(),
		"stats": RunState.run_stats.duplicate(),
	}
	EventBus.run_ended.emit(victory)
	RunState.clear()
	go_to_screen(&"run_summary")


func abandon_run() -> void:
	end_run(false)
