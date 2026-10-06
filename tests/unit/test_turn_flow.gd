extends TestCase


func test_opening_hand_and_energy() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	check_eq(combat.phase, CombatState.Phase.PLAYER_TURN, "player acts first")
	check_eq(combat.hand.size(), 5, "draws 5")
	check_eq(combat.draw_pile.size(), 5, "5 left in draw pile")
	check_eq(combat.player.energy, 3, "3 energy")


func test_piles_cycle_and_reshuffle() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	combat.end_player_turn()
	check_eq(combat.hand.size(), 5, "turn 2 hand")
	check_eq(combat.draw_pile.size(), 0, "draw pile used up")
	check_eq(combat.discard_pile.size(), 5, "turn 1 hand discarded")
	combat.end_player_turn()
	check_eq(combat.hand.size(), 5, "turn 3 hand after reshuffle")
	check_eq(combat.draw_pile.size() + combat.discard_pile.size() + combat.hand.size(), 10, "no cards lost")
	check_eq(combat.player.energy, 3, "energy refilled")


func test_block_resets_each_turn() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	combat.gain_block(combat.player, 7)
	combat.end_player_turn()
	check_eq(combat.player.block, 0, "block cleared at start of player turn")


func test_play_restrictions() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	var strike := Fixtures.give(combat, &"warden_strike")
	check_eq(combat.can_play(strike, null), "Choose a target", "single-target needs a target")
	combat.player.energy = 0
	check_eq(combat.can_play(strike, combat.enemies[0]), "Not enough energy", "costs energy")
	check(not combat.play_card(strike, combat.enemies[0]), "refused")
	check(combat.hand.has(strike), "stays in hand")


func test_power_leaves_play() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	var aegis := Fixtures.give(combat, &"searing_aegis")
	combat.play_card(aegis)
	check_eq(combat.player.get_stacks(&"searing_aegis"), 2, "power applied as status")
	check(not combat.discard_pile.has(aegis) and not combat.hand.has(aegis), "power card left play")


func test_exhaust_keyword() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	var muck := Fixtures.give(combat, &"muck")
	combat.play_card(muck)
	check(combat.exhaust_pile.has(muck), "Muck exhausts")


func test_victory() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(5)])
	combat.start()
	combat.play_card(Fixtures.give(combat, &"warden_strike"), combat.enemies[0])
	check_eq(combat.result, CombatState.Result.VICTORY, "victory")
	check(combat.is_over(), "combat over")


func test_defeat() -> void:
	var combat := Fixtures.combat([Fixtures.attacker_enemy(100)], [], false, 1, 10)
	combat.start()
	combat.end_player_turn()
	check_eq(combat.result, CombatState.Result.DEFEAT, "defeat")
	check_eq(combat.player.hp, 0, "hp floors at 0")


func test_same_seed_same_fight() -> void:
	var a := Fixtures.combat([Fixtures.dummy_enemy(100)], [], false, 99)
	var b := Fixtures.combat([Fixtures.dummy_enemy(100)], [], false, 99)
	a.start()
	b.start()
	var ids_a := a.hand.map(func(c): return c.data.id)
	var ids_b := b.hand.map(func(c): return c.data.id)
	check_eq(ids_a, ids_b, "same seed draws the same opening hand")
