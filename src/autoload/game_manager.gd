extends Node
## High-level game flow (autoload: GameManager).
##
## The only place that decides what screen comes next. Screens report what the
## player did (picked a map node, won a fight, left the shop) and GameManager
## routes: main menu → class select → map → node screen → rewards → map …
## → boss → run summary.

const MAX_ASCENSION := 15
## Acts with content. The run is won after this act's boss.
const FINAL_ACT := 2

const SCREENS := {
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
## Combat started from an event: rewards include a relic.
var pending_fight_bonus_relic := false
## Rewards for the reward screen, and its title.
var pending_rewards: Array[Dictionary] = []
var reward_title := "Rewards"
var pending_event: EventData
## Snapshot taken in end_run() for the run-summary screen.
var last_run_summary: Dictionary = {}


func go_to_screen(screen_id: StringName) -> void:
	var path: String = SCREENS.get(screen_id, SCREENS[&"main_menu"])
	if not ResourceLoader.exists(path):
		push_warning("GameManager: screen '%s' not built yet (%s)" % [screen_id, path])
		path = SCREENS[&"main_menu"]
	SceneRouter.go_to(path, screen_id)


# --- Run lifecycle --------------------------------------------------------------

func start_new_run(class_id: StringName, ascension: int = 0, run_seed: int = -1) -> void:
	var class_data := ContentDB.get_character_class(class_id)
	if class_data == null:
		push_error("GameManager: unknown class %s" % class_id)
		return
	if run_seed < 0:
		run_seed = randi()
	RunState.start(class_data, clampi(ascension, 0, MAX_ASCENSION), run_seed)
	RunState.map_data = MapGenerator.generate(RunState.rng.get_stream(&"map"), 1, RunState.ascension)
	MetaProgress.stats["runs_started"] += 1
	MetaProgress.save_meta()
	EventBus.run_started.emit(class_id, ascension, run_seed)
	EventBus.act_started.emit(1)
	RunState.save_run()
	go_to_screen(&"map")


func continue_run() -> void:
	if RunState.load_run():
		go_to_screen(&"map")
	else:
		push_warning("GameManager: saved run is missing or invalid; discarding it")
		RunState.clear()
		go_to_screen(&"main_menu")


## Called when the player dies, beats the final boss, or abandons the run.
func end_run(victory: bool) -> void:
	var floors := RunState.total_floor()
	var bosses := RunState.act - 1 + (1 if victory else 0)
	var xp := floors * 5 + bosses * 25 + (60 if victory else 0) + RunState.ascension * 10
	var meta := MetaProgress.record_run(RunState.class_id, victory, floors, RunState.ascension, xp)
	MetaProgress.stats["enemies_killed"] += int(RunState.run_stats.get("enemies_killed", 0))
	MetaProgress.save_meta()
	last_run_summary = {
		"victory": victory, "class_id": RunState.class_id, "ascension": RunState.ascension,
		"act": RunState.act, "floor": floors, "xp": xp, "gold": RunState.gold,
		"hp": RunState.hp, "max_hp": RunState.max_hp,
		"deck": RunState.deck.duplicate(), "relics": RunState.relics.duplicate(),
		"stats": RunState.run_stats.duplicate(), "seed": RunState.rng.seed_value,
		"meta": meta,
	}
	EventBus.run_ended.emit(victory)
	RunState.clear()
	go_to_screen(&"run_summary")


func abandon_run() -> void:
	end_run(false)


# --- Map flow -------------------------------------------------------------------

func select_map_node(node_id: String) -> void:
	if not MapGenerator.reachable(RunState.map_data, RunState.current_node).has(node_id):
		push_warning("GameManager: node %s is not reachable" % node_id)
		return
	RunState.current_node = node_id
	RunState.visited_nodes.append(node_id)
	var node := RunState.current_map_node()
	RunState.floor_number = int(node.floor) + 1
	EventBus.map_node_selected.emit(node)
	match String(node.type):
		MapGenerator.TYPE_MONSTER, MapGenerator.TYPE_ELITE, MapGenerator.TYPE_BOSS:
			start_combat(RunLogic.pick_encounter(node.type))
		MapGenerator.TYPE_REST:
			go_to_screen(&"rest")
		MapGenerator.TYPE_SHOP:
			go_to_screen(&"shop")
		MapGenerator.TYPE_TREASURE:
			show_rewards(RunLogic.treasure_rewards(), "Treasure")
		MapGenerator.TYPE_EVENT:
			pending_event = RunLogic.pick_event()
			if pending_event:
				go_to_screen(&"event")
			else:
				start_combat(RunLogic.pick_encounter(MapGenerator.TYPE_MONSTER))


func start_combat(encounter: EncounterData, bonus_relic: bool = false) -> void:
	pending_encounter = encounter
	pending_fight_bonus_relic = bonus_relic
	go_to_screen(&"combat")


## Milestone 1 shortcut kept for tests: start (or continue) a run and jump
## straight into a random Act 1 fight.
func start_debug_combat(class_id: StringName = &"pyre_warden") -> void:
	if not RunState.active:
		RunState.start(ContentDB.get_character_class(class_id), 0, randi())
	pending_encounter = null
	go_to_screen(&"combat")


func on_combat_won(final_hp: int) -> void:
	RunState.set_hp(final_hp)
	var node := RunState.current_map_node()
	var node_type: String = node.get("type", MapGenerator.TYPE_MONSTER)
	if node_type == MapGenerator.TYPE_MONSTER or node_type == MapGenerator.TYPE_EVENT:
		RunState.monster_fights += 1
	if node_type == MapGenerator.TYPE_BOSS:
		MetaProgress.stats["bosses_killed"] += 1
		if RunState.act >= FINAL_ACT:
			end_run(true)
			return
	var title := "Victory!"
	if node_type == MapGenerator.TYPE_ELITE:
		MetaProgress.stats["elites_killed"] += 1
		title = "Elite Defeated!"
	show_rewards(RunLogic.combat_rewards(node_type, pending_fight_bonus_relic), title)
	pending_fight_bonus_relic = false


func on_combat_lost() -> void:
	RunState.hp = 0
	end_run(false)


func show_rewards(rewards: Array[Dictionary], title: String) -> void:
	pending_rewards = rewards
	reward_title = title
	go_to_screen(&"reward")


## A node is finished: save and return to the map (the next act's map after
## a boss).
func complete_node() -> void:
	pending_rewards = []
	pending_event = null
	if String(RunState.current_map_node().get("type", "")) == MapGenerator.TYPE_BOSS and RunState.act < FINAL_ACT:
		RunLogic.advance_act()
	RunState.save_run()
	go_to_screen(&"map")
