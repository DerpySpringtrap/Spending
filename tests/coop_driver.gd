extends "res://tests/flow_driver.gd"
## Co-op version of the flow driver: hosts or joins over localhost, then plays
## the run through the real screens. Votes differ on purpose (host takes the
## first reachable room, the client the last) to exercise the tie-break.

var _role := "host"
var _port := 24799
var _last_vote_key := ""
var _synced := 0


func _ready() -> void:
	_class_id = &"rootmother"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			_role = arg.trim_prefix("--role=")
		elif arg.begins_with("--port="):
			_port = int(arg.trim_prefix("--port="))
		elif arg.begins_with("--class="):
			_class_id = StringName(arg.trim_prefix("--class="))
		elif arg.begins_with("--nodes="):
			_max_nodes = int(arg.trim_prefix("--nodes="))
		elif arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	MetaProgress.unlock(&"class", _class_id)
	_visual = _shots_dir != "" and DisplayServer.get_name() != "headless"
	UIStyle.speed = 1.0 if _visual else 30.0
	RunState.clear()
	await _settle()
	await _connect()
	if _failures.is_empty():
		await _play()
	print("COOP TEST (%s): %s (screens: %s, syncs: %d)" % [_role, "PASS" if _failures.is_empty() else "FAIL", ", ".join(_seen.keys()), _synced])
	for f in _failures:
		print("  FAIL: ", f)
	UIStyle.speed = 1.0
	# Let the other side reach the same point before the connection closes.
	await get_tree().create_timer(3.0).timeout
	Coop.leave()
	get_tree().quit(0 if _failures.is_empty() else 1)


func _connect() -> void:
	_press(_find_button("Co-op"))
	await _settle()
	var lobby := get_tree().current_scene
	lobby._name_edit.text = _role.capitalize()
	if _role == "host":
		lobby._port_edit.text = str(_port)
		_press(_find_button("Host"))
		if not await _until(func(): return Coop.lobby.size() >= 2, 30.0):
			_failures.append("no one joined")
			return
		Coop.set_class(_class_id)
		await _until(func(): return Coop.lobby.all(func(p): return p.class_id != ""), 2.0)
		await get_tree().create_timer(1.0).timeout  # The client picks its hero.
		await _screen_shot("coop_lobby")
		_press(_find_button("Start Run"))
	else:
		lobby._address_edit.text = "127.0.0.1:%d" % _port
		_press(_find_button("Join"))
		if not await _until(func(): return Coop.state == Coop.State.LOBBY, 15.0):
			_failures.append("couldn't join: %s" % lobby._error.text)
			return
		Coop.set_class(_class_id)
	if not await _until(func(): return get_tree().current_scene and get_tree().current_scene.name == "MapScreen" \
			and not SceneRouter.is_transitioning, 20.0):
		_failures.append("run didn't start")


func _play() -> void:
	var nodes := 0
	var handled: Node = null
	var stall := 0.0
	while nodes < _max_nodes:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene == null or SceneRouter.is_transitioning:
			continue
		var name := String(scene.name)
		if name == "MainMenu":
			_failures.append("back at the main menu: %s" % GameManager.coop_message)
			return
		if name == "RunSummary":
			await _screen_shot("run_summary")
			return
		if name == "MapScreen":
			stall = 0.0 if scene != handled else stall + get_process_delta_time()
			if not GameManager.coop_waiting() and not GameManager.coop_votes.has(RunState.home_seat):
				var key := "%d:%s:%d" % [RunState.act, RunState.current_node, RunState.visited_nodes.size()]
				if key != _last_vote_key:
					_last_vote_key = key
					_print_sync()
					await _screen_shot("map")
					var options := MapGenerator.reachable(RunState.map_data, RunState.current_node)
					var pick: String = options[0] if _role == "host" else options[options.size() - 1]
					scene._on_node_chosen(pick)
					nodes += 1
			handled = scene
			if stall > 60.0:
				_failures.append("stuck on the map (waiting: %s)" % GameManager.coop_waiting())
				return
			continue
		if scene == handled:
			continue
		handled = scene
		match name:
			"CombatScreen":
				await _screen_shot("combat", 2.5)
				await _play_coop_combat(scene)
			"RewardScreen":
				await _screen_shot("reward")
				await _claim_rewards(scene)
			"RestScreen":
				await _screen_shot("rest")
				_press(scene._choices.get_child(0))
				await _wait(0.3)
				_press(scene._continue)
			"ShopScreen":
				await _screen_shot("shop")
				_press(_find_button("Leave"))
			"EventScreen":
				await _screen_shot("event")
				await _play_event(scene)
			_:
				_failures.append("unexpected scene %s" % name)
				return
	if not _seen.has("combat") or not _seen.has("map"):
		_failures.append("core screens not reached")


func _play_coop_combat(screen: Node) -> void:
	var guard := 0
	while is_instance_valid(screen) and screen.is_inside_tree() and guard < 20000:
		guard += 1
		if screen._result.visible:
			for b in screen._result._buttons.get_children():
				_press(b)
				break
			return
		if not screen.queue.is_busy():
			screen._autoplay()
		await get_tree().process_frame
		if get_tree().current_scene != screen:
			return
	_failures.append("combat never finished")


## One line per vote: both players must print the same thing.
func _print_sync() -> void:
	_synced += 1
	var parts: PackedStringArray = ["act %d" % RunState.act, "floor %d" % RunState.floor_number, "fights %d" % RunState.monster_fights]
	for s in RunState.seats:
		var ids: PackedStringArray = []
		for card in s.deck:
			ids.append(String(card.data.id) + ("+" if card.upgraded else ""))
		var relic_ids: PackedStringArray = []
		for relic in s.relics:
			relic_ids.append(String(relic.id))
		parts.append("%s %s %d/%d hp %dg deck[%s] relics[%s]" % [s.player_name, s.class_id, s.hp, s.max_hp, s.gold,
			",".join(ids), ",".join(relic_ids)])
	parts.append("rng %s" % str(RunState.shared_rng.to_dict().states))
	print("COOP SYNC %d: %s" % [_synced, " | ".join(parts)])


func _until(condition: Callable, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if condition.call():
			return true
		await get_tree().process_frame
		waited += get_process_delta_time()
	return condition.call()
