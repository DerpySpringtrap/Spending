extends Node
## Plays a run through the real UI: presses buttons, picks map nodes (trying
## every room type), auto-plays fights, claims rewards. Fails on stalls.

var _shots_dir := ""
var _max_nodes := 30
var _seen := {}
var _failures: PackedStringArray = []
var _visual := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		elif arg.begins_with("--nodes="):
			_max_nodes = int(arg.trim_prefix("--nodes="))
	_visual = _shots_dir != "" and DisplayServer.get_name() != "headless"
	UIStyle.speed = 1.0 if _visual else 30.0
	RunState.clear()
	await _settle()
	await _run()
	print("FLOW TEST: %s (screens: %s)" % ["PASS" if _failures.is_empty() else "FAIL", ", ".join(_seen.keys())])
	for f in _failures:
		print("  FAIL: ", f)
	UIStyle.speed = 1.0
	RunState.clear()
	get_tree().quit(0 if _failures.is_empty() else 1)


func _run() -> void:
	await _screen_shot("main_menu")
	_press(_find_button("New Run"))
	await _settle()
	await _screen_shot("class_select")
	var cs := get_tree().current_scene
	cs._seed_edit.text = "2024"
	_press(_find_button("Embark"))
	await _settle()
	for step in _max_nodes:
		var scene := get_tree().current_scene
		var name := String(scene.name)
		match name:
			"MapScreen":
				await _screen_shot("map")
				_choose_node(scene)
			"CombatScreen":
				await _screen_shot("combat", 2.5)
				await _play_combat(scene)
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
			"RunSummary":
				await _screen_shot("run_summary", 1.0)
				return
			_:
				_failures.append("unexpected scene %s" % name)
				return
		var changed := await _settle(scene)
		if not changed:
			_failures.append("stuck on %s" % name)
			return
	if not _seen.has("combat") or not _seen.has("reward") or not _seen.has("map"):
		_failures.append("core screens not reached")


func _choose_node(map_screen: Node) -> void:
	var options := MapGenerator.reachable(RunState.map_data, RunState.current_node)
	var best := options[0]
	var best_score := -99
	for id in options:
		var t: String = RunState.map_data.nodes[id].type
		var score := 0 if _seen.has(_screen_for(t)) else 10
		if t == "elite" and RunState.hp < RunState.max_hp * 0.6:
			score -= 20
		if score > best_score:
			best_score = score
			best = id
	map_screen._view.buttons[best].chosen.emit(best)


func _screen_for(type: String) -> String:
	match type:
		"monster", "elite", "boss": return "combat"
		"treasure": return "reward"
	return type


func _play_combat(screen: Node) -> void:
	var guard := 0
	while is_instance_valid(screen) and screen.is_inside_tree() and guard < 4000:
		guard += 1
		if screen._result.visible:
			for b in screen._result._buttons.get_children():
				_press(b)
				break
			return
		if screen._can_act():
			if guard == 1 and _visual:
				await _wait(0.5)
			screen._autoplay()
		await get_tree().process_frame
		if get_tree().current_scene != screen:
			return


func _claim_rewards(screen: Node) -> void:
	for row in screen._rows.get_children():
		if row is Button and not row.disabled:
			var reward: Dictionary = row.get_meta("reward")
			_press(row)
			await _wait(0.2)
			if String(reward.type) == "card" and screen._card_overlay:
				await _screen_shot("card_reward", 0.6)
				var views: Array = screen._card_overlay.get_meta("views")
				var e := InputEventMouseButton.new()
				e.button_index = MOUSE_BUTTON_LEFT
				e.pressed = true
				views[0].pressed.emit(views[0], e)
				await _wait(0.9)
	await _wait(0.3)
	_press(screen._proceed)


func _play_event(screen: Node) -> void:
	for b in screen._choices.get_children():
		if b is Button and not b.disabled:
			_press(b)
			break
	await _wait(0.3)
	if not is_instance_valid(screen) or get_tree().current_scene != screen:
		return
	if screen._picker.visible:
		var view = screen._picker._grid.get_child(0)
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = true
		view.pressed.emit(view, e)
		await _wait(1.0)
	var cont := _find_button("Continue")
	if cont:
		_press(cont)


# --- Helpers ----------------------------------------------------------------------

func _press(button: BaseButton) -> void:
	if button == null:
		_failures.append("button not found in %s" % get_tree().current_scene.name)
		return
	button.pressed.emit()


func _find_button(text: String, node: Node = null) -> Button:
	if node == null:
		node = get_tree().current_scene
	for child in node.get_children():
		if child is Button and child.text.begins_with(text) and child.visible:
			return child
		var found := _find_button(text, child)
		if found:
			return found
	return null


## Waits until the current scene differs from [param from] and the transition
## has finished. Returns false on timeout.
func _settle(from: Node = null) -> bool:
	var frames := 0
	while frames < 2400:
		await get_tree().process_frame
		frames += 1
		var current := get_tree().current_scene
		if current != null and current != from and not SceneRouter.is_transitioning:
			await _wait(0.2)
			return true
	return false


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds / (1.0 if _visual else 10.0)).timeout


func _screen_shot(key: String, delay: float = 0.6) -> void:
	if _seen.has(key):
		return
	_seen[key] = true
	if not _visual:
		return
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shots_dir.path_join("%02d_%s.png" % [10 + _seen.size(), key]))
