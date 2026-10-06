extends Node
## Drives the real combat screen like a player: selects and targets cards,
## then auto-plays to the end. Saves screenshots when a display is available.
## godot --path . res://tests/ui_smoke_test.tscn -- --shots=/some/dir
## (works headless too: screenshots are skipped)

var _shots_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	RunState.start(ContentDB.get_character_class(&"pyre_warden"), 0, 12345)
	GameManager.pending_encounter = ContentDB.get_encounter(&"a1_two_toads")
	var screen: Control = load("res://src/combat/combat_screen.tscn").instantiate()
	add_child(screen)
	await _frames(3)
	var combat: CombatState = screen.combat
	var ok := combat != null and combat.hand.size() == 5
	await _shot("01_opening_hand")

	# Select the first single-target card and hover a target (live preview).
	for card in combat.hand:
		if card.data.target_mode == CardData.TargetMode.SINGLE_ENEMY:
			screen._on_card_pressed(card)
			screen._set_hover_target(combat.enemies[0])
			await _frames(2)
			await _shot("02_targeting")
			var hp_before := combat.enemies[0].hp
			screen._on_enemy_pressed(combat.enemies[0])
			await _frames(2)
			ok = ok and combat.enemies[0].hp < hp_before
			break

	var guard := 0
	while not combat.is_over() and guard < 50:
		screen._autoplay()
		await _frames(1)
		guard += 1
	await _frames(3)
	await _shot("03_result")
	ok = ok and combat.is_over() and screen._overlay.visible
	print("UI SMOKE TEST: %s (result=%s, rounds=%d)" % ["PASS" if ok else "FAIL", CombatState.Result.keys()[combat.result], combat.round_number])
	RunState.clear()
	get_tree().quit(0 if ok else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	if _shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shots_dir.path_join(name + ".png"))
