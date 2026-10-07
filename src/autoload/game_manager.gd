extends Node
## High-level game flow (autoload: GameManager).
##
## The only place that decides what screen comes next. Screens report what the
## player did (picked a map node, won a fight, left the shop) and GameManager
## routes: main menu → class select → map → node screen → rewards → map …
## → boss → run summary.

const MAX_ASCENSION := 15
## The run is won after this act's boss. Act 4 (the Umbral Core) joins once
## the player has beaten Act 3 at least once (see final_act()).
const FINAL_ACT := 3
const SECRET_ACT := 4


## The last act of a run started now.
func final_act() -> int:
	return SECRET_ACT if MetaProgress.act4_unlocked else FINAL_ACT

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
	&"coop_lobby": "res://src/ui/screens/coop_lobby/coop_lobby.tscn",
}

## Co-op: a fallen hero gets back up after a won fight with this share of max HP.
const COOP_REVIVE_HP := 0.1

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

# --- Co-op state (see the Co-op section) ---
## seat -> map node id the player voted for.
var coop_votes: Dictionary = {}
## seat -> true once the player finished the current node (rewards, shop...).
var coop_done: Dictionary = {}
## The combat screen applies combat commands; until it's ready they wait here.
var coop_combat_handler: Callable
var _coop_combat_inbox: Array = []
## Shown on the main menu after a co-op run ends abruptly.
var coop_message := ""
## The last such message (kept for tests; coop_message is cleared once shown).
var coop_last_abort := ""


func _ready() -> void:
	Coop.run_starting.connect(start_coop_run)
	Coop.command_received.connect(_on_coop_command)


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
	RunState.map_data = MapGenerator.generate(RunState.shared_rng.get_stream(&"map"), 1, RunState.ascension)
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
	var at_boss := String(RunState.current_map_node().get("type", "")) == MapGenerator.TYPE_BOSS
	var reached_act2_boss := victory or RunState.act > 2 or (RunState.act == 2 and at_boss)
	var beat_act2_boss := victory or RunState.act > 2
	var meta := MetaProgress.record_run(RunState.class_id, victory, floors, RunState.ascension, xp, reached_act2_boss, beat_act2_boss,
			victory and RunState.act >= FINAL_ACT)
	var party: Array = []
	if RunState.coop:
		for s in RunState.seats:
			party.append({"name": s.player_name, "class_id": s.class_id, "hp": s.hp, "max_hp": s.max_hp})
		Coop.finish()
	MetaProgress.stats["enemies_killed"] += int(RunState.run_stats.get("enemies_killed", 0))
	MetaProgress.save_meta()
	last_run_summary = {
		"victory": victory, "class_id": RunState.class_id, "ascension": RunState.ascension,
		"act": RunState.act, "floor": floors, "xp": xp, "gold": RunState.gold,
		"hp": RunState.hp, "max_hp": RunState.max_hp,
		"deck": RunState.deck.duplicate(), "relics": RunState.relics.duplicate(),
		"stats": RunState.run_stats.duplicate(), "seed": RunState.shared_rng.seed_value,
		"meta": meta, "party": party,
	}
	EventBus.run_ended.emit(victory)
	RunState.clear()
	go_to_screen(&"run_summary")


func abandon_run() -> void:
	var was_coop := RunState.coop
	end_run(false)
	if was_coop:
		Coop.leave()  # The others get a "left the game" notice.


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
	var node := RunState.current_map_node()
	var node_type: String = node.get("type", MapGenerator.TYPE_MONSTER)
	if not RunState.coop:
		# Co-op results were already applied for every player (coop_combat_resolved).
		RunState.set_hp(final_hp)
		if node_type == MapGenerator.TYPE_MONSTER or node_type == MapGenerator.TYPE_EVENT:
			RunState.monster_fights += 1
	if node_type == MapGenerator.TYPE_BOSS:
		MetaProgress.stats["bosses_killed"] += 1
		if RunState.act >= RunState.final_act:
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


## The party left the node behind (rewards taken, shop left...). Co-op: tell
## the others and wait on the map until everyone is done.
func _finish_node_coop() -> void:
	pending_rewards = []
	pending_event = null
	go_to_screen(&"map")
	Coop.send({"t": "done", "snap": RunState.home().to_dict()})


func show_rewards(rewards: Array[Dictionary], title: String) -> void:
	pending_rewards = rewards
	reward_title = title
	go_to_screen(&"reward")


## A node is finished: save and return to the map (the next act's map after
## a boss).
func complete_node() -> void:
	if RunState.coop:
		_finish_node_coop()
		return
	pending_rewards = []
	pending_event = null
	if String(RunState.current_map_node().get("type", "")) == MapGenerator.TYPE_BOSS and RunState.act < RunState.final_act:
		RunLogic.advance_act()
	RunState.save_run()
	go_to_screen(&"map")


# =============================================================================
# Co-op
# =============================================================================
# Every client runs the same run. Shared steps (choosing the next map node,
# combat) happen through commands that every client applies in the same
# order; personal steps (rewards, shop, rest, events) run locally and end with
# a "done" command carrying the player's whole seat. The map waits until
# everyone is done, then the players vote on the next node.

## Coop.run_starting: build the run every client shares.
func start_coop_run(payload: Dictionary, my_seat: int) -> void:
	coop_votes.clear()
	coop_done.clear()
	_coop_combat_inbox.clear()
	coop_message = ""
	RunState.start_coop(payload.players, int(payload.ascension), int(payload.seed), int(payload.final_act), my_seat)
	RunState.map_data = MapGenerator.generate(RunState.shared_rng.get_stream(&"map"), 1, RunState.ascension)
	MetaProgress.stats["runs_started"] += 1
	MetaProgress.save_meta()
	EventBus.run_started.emit(RunState.class_id, RunState.ascension, int(payload.seed))
	EventBus.act_started.emit(1)
	go_to_screen(&"map")


## True while the local player has finished the node but others haven't.
func coop_waiting() -> bool:
	return RunState.coop and not coop_done.is_empty() and coop_done.size() < RunState.seats.size()


## Names of the players still busy with the current node.
func coop_busy_players() -> PackedStringArray:
	var out: PackedStringArray = []
	for s in RunState.seats:
		if not coop_done.has(s.index):
			out.append(s.player_name)
	return out


## Map screen: the local player picks the next node.
func coop_vote(node_id: String) -> void:
	if coop_waiting() or not MapGenerator.reachable(RunState.map_data, RunState.current_node).has(node_id):
		return
	Coop.send({"t": "vote", "node": node_id})


func _on_coop_command(cmd: Dictionary) -> void:
	if not RunState.active or not RunState.coop:
		return
	var seat := int(cmd.get("seat", 0))
	match String(cmd.get("t", "")):
		"vote":
			coop_votes[seat] = String(cmd.node)
			EventBus.coop_state_changed.emit()
			if coop_votes.size() >= RunState.seats.size():
				_coop_resolve_votes()
		"done":
			if seat != RunState.home_seat:
				RunState.seats[seat].from_dict(cmd.snap)
			coop_done[seat] = true
			EventBus.coop_state_changed.emit()
			if coop_done.size() >= RunState.seats.size():
				_coop_all_done()
		_:
			# Combat commands go to the combat screen, in order.
			_coop_combat_inbox.append(cmd)
			_coop_pump_combat()


## The combat screen registers (or clears) its handler; queued commands flow.
func set_coop_combat_handler(handler: Callable) -> void:
	coop_combat_handler = handler
	_coop_pump_combat()


func _coop_pump_combat() -> void:
	while not _coop_combat_inbox.is_empty() and coop_combat_handler.is_valid():
		coop_combat_handler.call(_coop_combat_inbox.pop_front())


## Everyone voted: the shared node is the agreed one, or a seeded pick among
## the votes when they differ.
func _coop_resolve_votes() -> void:
	var votes: Array = []
	for s in RunState.seats:
		votes.append(coop_votes.get(s.index, ""))
	coop_votes.clear()
	var node_id: String = votes[0]
	var unique := {}
	for v in votes:
		unique[v] = true
	if unique.size() > 1:
		node_id = RunState.shared_rng.pick(votes, &"misc")
	EventBus.coop_state_changed.emit()
	select_map_node(node_id)


## Everyone finished the node: on to the next act after a boss, then the map.
func _coop_all_done() -> void:
	coop_done.clear()
	if String(RunState.current_map_node().get("type", "")) == MapGenerator.TYPE_BOSS and RunState.act < RunState.final_act:
		RunLogic.advance_act()
		go_to_screen(&"map")  # Redraw for the new act.
	EventBus.coop_state_changed.emit()


## Called by the combat screen the moment a co-op fight ends (in command
## order, on every client): write each hero's result back to their seat.
func coop_combat_resolved(combat: CombatState) -> void:
	_coop_combat_inbox.clear()
	if combat.result != CombatState.Result.VICTORY:
		return
	for i in combat.seats.size():
		var hero := combat.seats[i].player
		var gold := combat.seats[i].player_gold
		RunState.with_seat(i, func():
			var hp := hero.hp
			if hero.is_dead:
				hp = maxi(1, ceili(RunState.max_hp * COOP_REVIVE_HP))
			RunState.set_hp(hp)
			RunState.add_gold(gold - RunState.gold))
	var node_type: String = RunState.current_map_node().get("type", MapGenerator.TYPE_MONSTER)
	if node_type == MapGenerator.TYPE_MONSTER or node_type == MapGenerator.TYPE_EVENT:
		RunState.monster_fights += 1


## The session broke mid-run (someone left or the connection dropped).
func coop_abort(reason: String) -> void:
	coop_message = reason
	coop_last_abort = reason
	coop_votes.clear()
	coop_done.clear()
	_coop_combat_inbox.clear()
	coop_combat_handler = Callable()
	if RunState.active:
		RunState.clear()
	go_to_screen(&"main_menu")
