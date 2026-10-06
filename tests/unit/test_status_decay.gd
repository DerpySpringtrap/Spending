extends TestCase


func _weakening_enemy() -> EnemyData:
	var e := Fixtures.dummy_enemy(100, "Hexer")
	var weak := ApplyStatusEffect.new()
	weak.status = Fixtures.status(&"weak")
	weak.amount = 1
	var hex := EnemyMoveData.new()
	hex.id = &"hex"
	hex.intent = EnemyMoveData.Intent.DEBUFF
	hex.effects.assign([weak])
	e.phases[0].moves.assign([hex])
	return e


func test_enemy_applied_weak_covers_next_player_turn() -> void:
	var combat := Fixtures.combat([_weakening_enemy()])
	combat.start()
	combat.end_player_turn()
	check_eq(combat.player.get_stacks(&"weak"), 1, "1 Weak survives into the player's turn")
	# The enemy re-applies each turn; stop it to watch the decay.
	combat.enemies[0].data = Fixtures.dummy_enemy(100)
	combat.enemies[0].next_move = null
	combat.end_player_turn()
	check(not combat.player.has_status(&"weak"), "expires after one player turn")


func test_player_applied_vulnerable_duration() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	var enemy := combat.enemies[0]
	combat.apply_status(enemy, Fixtures.status(&"vulnerable"), 2)
	combat.end_player_turn()
	check_eq(enemy.get_stacks(&"vulnerable"), 1, "2 Vulnerable lasts into the next player turn")
	combat.end_player_turn()
	check(not enemy.has_status(&"vulnerable"), "then expires")


func test_stun_skips_enemy_turn() -> void:
	var combat := Fixtures.combat([Fixtures.attacker_enemy(10)])
	combat.start()
	var enemy := combat.enemies[0]
	combat.apply_status(enemy, Fixtures.status(&"stun"), 1)
	check_eq(combat.get_intent_damage(enemy), Vector2i.ZERO, "stunned enemies show no attack")
	combat.end_player_turn()
	check_eq(combat.player.hp, 80, "stunned enemy didn't attack")
	check(not enemy.has_status(&"stun"), "stun wears off")
	combat.end_player_turn()
	check_eq(combat.player.hp, 70, "attacks again next turn")


func test_ember_shell_keeps_block_for_one_turn() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	combat.gain_block(combat.player, 10)
	combat.apply_status(combat.player, Fixtures.status(&"ember_shell"), 1)
	combat.end_player_turn()
	check_eq(combat.player.block, 10, "block retained")
	check(not combat.player.has_status(&"ember_shell"), "shell used up")
	combat.end_player_turn()
	check_eq(combat.player.block, 0, "block cleared normally afterwards")


func test_flag_status_does_not_stack() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	combat.apply_status(combat.player, Fixtures.status(&"eternal_pyre"), 1)
	combat.apply_status(combat.player, Fixtures.status(&"eternal_pyre"), 1)
	check_eq(combat.player.get_stacks(&"eternal_pyre"), 1, "flag stays at 1")
