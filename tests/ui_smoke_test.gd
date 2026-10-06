extends Node
## Drives the real combat screen with real input events (mouse drag-to-play,
## keyboard targeting), then auto-plays to the end. After every burst of
## animation it checks that everything displayed (HP, block, statuses,
## intents, hand, piles, energy, Heat) matches the combat state: proof that
## the views are built purely from the replayed EventBus beats.
##
## godot --headless --path . res://tests/ui_smoke_test.tscn
## With a display, add `-- --shots=<dir>` to save screenshots.

var _shots_dir := ""
var _screen: Control
var _combat: CombatState
var _failures: PackedStringArray = []
var _checks := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	var visual := _shots_dir != "" and DisplayServer.get_name() != "headless"
	UIStyle.speed = 1.0 if visual else 40.0
	RunState.start(ContentDB.get_character_class(&"pyre_warden"), 0, 4242)
	GameManager.pending_encounter = ContentDB.get_encounter(&"a1_toad_and_beetle")
	_screen = load("res://src/combat/combat_screen.tscn").instantiate()
	add_child(_screen)
	_combat = _screen.combat
	await _idle()
	_verify("opening")
	await _shot("01_opening_hand")

	await _drag_play_single_target()
	await _keyboard_play()

	var guard := 0
	var shot_enemy_turn := false
	while not _combat.is_over() and guard < 40:
		guard += 1
		if guard == 2 and visual and not shot_enemy_turn:
			shot_enemy_turn = true
			_screen._end_player_turn()
			await _wait_seconds(1.6)
			await _shot("04_enemy_turn")
		else:
			_screen._autoplay()
		await _idle()
		_verify("round %d" % _combat.round_number)
	await _idle()
	await _wait_seconds(0.6 if visual else 0.1)
	await _shot("05_result")
	if not _screen._result.visible:
		_failures.append("result overlay not shown")
	var ok := _failures.is_empty() and _combat.is_over()
	for f in _failures:
		print("  FAIL: ", f)
	print("UI SMOKE TEST: %s (%d consistency checks, result=%s, rounds=%d)" % [
		"PASS" if ok else "FAIL", _checks, CombatState.Result.keys()[_combat.result], _combat.round_number])
	UIStyle.speed = 1.0
	RunState.clear()
	get_tree().quit(0 if ok else 1)


# --- Scenarios ------------------------------------------------------------------

func _drag_play_single_target() -> void:
	var view: CardView = null
	for v in _screen._hand.get_views():
		if v.card.data.target_mode == CardData.TargetMode.SINGLE_ENEMY and _combat.is_affordable(v.card):
			view = v
			break
	if view == null:
		_failures.append("no single-target card in opening hand")
		return
	var enemy := _combat.living_enemies()[0]
	var hp_before := enemy.hp
	var energy_before := _combat.player.energy
	var start: Vector2 = view.global_position + view.pivot_offset - Vector2(0, 120)
	var target: Vector2 = _screen._views[enemy.id].hit_point()
	_mouse_button(start, true)
	await _frames(3)
	for k in 6:
		_mouse_motion(start.lerp(target, (k + 1) / 6.0))
		await _frames(1)
	await _frames(2)
	if not _screen._views[enemy.id].targeted:
		_failures.append("enemy not highlighted while dragging over it")
	await _shot("02_drag_targeting")
	_mouse_button(target, false)
	await _idle()
	_verify("after drag play")
	if _combat.player.energy >= energy_before or enemy.hp >= hp_before and enemy.block == 0:
		_failures.append("drag-to-play did not play the card (energy %d -> %d, hp %d -> %d)" % [energy_before, _combat.player.energy, hp_before, enemy.hp])


func _keyboard_play() -> void:
	var energy_before := _combat.player.energy
	if energy_before <= 0 or _combat.is_over():
		return
	# Focus the first affordable card with the arrow keys, then Accept.
	var index := -1
	for i in _combat.hand.size():
		if _combat.is_affordable(_combat.hand[i]):
			index = i
			break
	if index < 0:
		return
	for i in index + 1:
		_action("ui_right")
		await _frames(1)
	await _shot("03_keyboard_focus")
	_action("ui_accept")
	await _frames(2)
	if _screen._mode == _screen.Mode.TARGETING:
		_action("ui_right")
		await _frames(1)
		_action("ui_accept")
	await _idle()
	_verify("after keyboard play")
	if _combat.player.energy >= energy_before:
		_failures.append("keyboard play did not spend energy")


# --- Consistency check ----------------------------------------------------------

func _verify(label: String) -> void:
	_checks += 1
	var combatants: Array[Combatant] = [_combat.player]
	combatants.append_array(_combat.enemies)
	for c in combatants:
		var v: CombatantView = _screen._views[c.id]
		if c.is_dead:
			_expect(v.is_dead_shown(), label, "%s should show as dead" % c.display_name)
			continue
		_expect(v.get_health_bar().get_shown_hp() == c.hp, label, "%s HP shown %d, actual %d" % [c.display_name, v.get_health_bar().get_shown_hp(), c.hp])
		_expect(v.get_health_bar().get_shown_block() == c.block, label, "%s block shown %d, actual %d" % [c.display_name, v.get_health_bar().get_shown_block(), c.block])
		var actual := {}
		for id in c.statuses:
			if not c.status_data[id].hidden:
				actual[id] = c.statuses[id]
		_expect(v.get_status_tray().get_shown() == actual, label, "%s statuses shown %s, actual %s" % [c.display_name, v.get_status_tray().get_shown(), actual])
		if c is EnemyCombatant and not _combat.is_over():
			var intent := v.get_intent_view()
			var expected_move: EnemyMoveData = null if c.skips_turn() else c.next_move
			_expect(intent.move == expected_move, label, "%s intent shown %s, actual %s" % [c.display_name, intent.move, expected_move])
			var dmg := _combat.get_intent_damage(c)
			_expect(intent.damage == dmg.x, label, "%s intent damage shown %d, actual %d" % [c.display_name, intent.damage, dmg.x])
	if _combat.is_over():
		return
	var shown_hand: Array = _screen._hand.get_views().map(func(v): return v.card.uid)
	var actual_hand: Array = _combat.hand.map(func(c): return c.uid)
	_expect(shown_hand == actual_hand, label, "hand shown %s, actual %s" % [shown_hand, actual_hand])
	_expect(_screen._counts.draw == _combat.draw_pile.size(), label, "draw count %d vs %d" % [_screen._counts.draw, _combat.draw_pile.size()])
	_expect(_screen._counts.discard == _combat.discard_pile.size(), label, "discard count %d vs %d" % [_screen._counts.discard, _combat.discard_pile.size()])
	_expect(_screen._counts.exhaust == _combat.exhaust_pile.size(), label, "exhaust count %d vs %d" % [_screen._counts.exhaust, _combat.exhaust_pile.size()])
	_expect(_screen._energy.current == _combat.player.energy, label, "energy %d vs %d" % [_screen._energy.current, _combat.player.energy])
	_expect(_screen._gauge.value == _combat.player.resource_value, label, "heat %d vs %d" % [_screen._gauge.value, _combat.player.resource_value])


func _expect(condition: bool, label: String, message: String) -> void:
	if not condition:
		_failures.append("[%s] %s" % [label, message])


# --- Input & timing helpers -----------------------------------------------------

func _mouse_button(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	get_viewport().push_input(e, true)


func _mouse_motion(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(e, true)


func _action(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	get_viewport().push_input(e, true)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	get_viewport().push_input(up, true)


func _idle() -> void:
	var frames := 0
	await _frames(2)
	while _screen.queue.is_busy() and frames < 3000:
		await get_tree().process_frame
		frames += 1
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait_seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(shot_name: String) -> void:
	if _shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shots_dir.path_join(shot_name + ".png"))
