extends TestCase


func test_weighted_ai_respects_max_consecutive() -> void:
	var lurker := ContentDB.get_enemy(&"bog_lurker")
	var enemy := EnemyCombatant.new(lurker, 40)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for i in 300:
		var move := EnemyAI.choose_by_rules(enemy, rng)
		enemy.move_history.append(move.id)
		seen[move.id] = true
		if move.max_consecutive > 0:
			check(enemy.consecutive_uses(move.id) <= move.max_consecutive, "%s used too many times in a row" % move.id)
	check_eq(seen.size(), 3, "every move gets used")


func test_sequence_ai() -> void:
	var data := Fixtures.dummy_enemy(10)
	var moves: Array[EnemyMoveData] = []
	for id in [&"a", &"b", &"c"]:
		var m := EnemyMoveData.new()
		m.id = id
		moves.append(m)
	data.phases[0].moves = moves
	data.phases[0].selection = EnemyPhaseData.Selection.SEQUENCE
	var enemy := EnemyCombatant.new(data, 10)
	var order := []
	for i in 4:
		order.append(EnemyAI.choose_by_rules(enemy, RandomNumberGenerator.new()).id)
	check_eq(order, [&"a", &"b", &"c", &"a"], "loops in order")


func test_mire_toad_toxic_burst() -> void:
	var toad := ContentDB.get_enemy(&"mire_toad")
	var combat := Fixtures.combat([toad, toad])
	combat.start()
	check(combat.enemies[0].has_status(&"toxic_burst"), "starts with Toxic Burst")
	combat.enemies[0].hp = 1
	combat.play_card(Fixtures.give(combat, &"warden_strike"), combat.enemies[0])
	check(combat.enemies[0].is_dead, "toad died")
	check_eq(combat.player.get_stacks(&"poison"), 2, "death applied 2 Poison to the player")


func test_thornback_starts_with_thorns() -> void:
	var combat := Fixtures.combat([ContentDB.get_enemy(&"thornback_beetle")])
	combat.start()
	check_eq(combat.enemies[0].get_stacks(&"thorns"), 2, "2 Thorns")


func test_croak_adds_muck() -> void:
	var toad := ContentDB.get_enemy(&"mire_toad")
	var combat := Fixtures.combat([toad])
	combat.start()
	var croak: EnemyMoveData
	for m in toad.phases[0].moves:
		if m.id == &"croak":
			croak = m
	combat.enemies[0].next_move = croak
	combat.end_player_turn()
	var found := false
	for c in combat.draw_pile + combat.discard_pile + combat.hand:
		found = found or c.data.id == &"muck"
	check(found, "Muck added to the player's deck")


func test_intent_damage_preview() -> void:
	var lurker := ContentDB.get_enemy(&"bog_lurker")
	var combat := Fixtures.combat([lurker])
	combat.start()
	var enemy := combat.enemies[0]
	for m in lurker.phases[0].moves:
		if m.id == &"lunge":
			enemy.next_move = m
	check_eq(combat.get_intent_damage(enemy), Vector2i(11, 1), "base intent")
	combat.apply_status(enemy, Fixtures.status(&"strength"), 2)
	check_eq(combat.get_intent_damage(enemy).x, 13, "includes Strength")
	combat.apply_status(enemy, Fixtures.status(&"weak"), 1)
	check_eq(combat.get_intent_damage(enemy).x, 9, "13 x0.75 floors to 9")
	combat.apply_status(combat.player, Fixtures.status(&"vulnerable"), 1)
	check_eq(combat.get_intent_damage(enemy).x, 14, "player's Vulnerable: 13 x0.75 x1.5 = 14.6")


func test_ascension_scaling() -> void:
	var lurker := ContentDB.get_enemy(&"bog_lurker")
	var cls := Fixtures.warden()
	var deck: Array[CardInstance] = []
	var relics: Array[RelicData] = []
	var combat := CombatState.create(cls, deck, 80, 80, relics, Fixtures.encounter([lurker]), 7, RngStreams.new(3))
	combat.start()
	var enemy := combat.enemies[0]
	check(enemy.max_hp >= 44 and enemy.max_hp <= 49, "A7: +10%% HP (got %d)" % enemy.max_hp)
	for m in lurker.phases[0].moves:
		if m.id == &"lunge":
			enemy.next_move = m
	check_eq(combat.get_intent_damage(enemy).x, 13, "A2+: 11 x1.1 rounds up to 13")
