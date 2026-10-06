extends TestCase


func test_strength_adds_damage_per_hit() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	combat.apply_status(combat.player, Fixtures.status(&"strength"), 2)
	var strike := Fixtures.give(combat, &"warden_strike")
	check(combat.play_card(strike, combat.enemies[0]), "strike played")
	check_eq(combat.enemies[0].hp, 92, "6 base + 2 Strength")


func test_weak_vulnerable_and_rounding() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	var enemy := combat.enemies[0]
	combat.apply_status(combat.player, Fixtures.status(&"weak"), 1)
	combat.apply_status(enemy, Fixtures.status(&"vulnerable"), 1)
	check_eq(DamageCalc.attack_damage(6, combat.player, enemy), 6, "6 x0.75 x1.5 = 6.75 floors to 6")
	combat.apply_status(combat.player, Fixtures.status(&"strength"), 2)
	check_eq(DamageCalc.attack_damage(6, combat.player, enemy), 9, "(6+2) x0.75 x1.5 = 9")
	combat.apply_status(combat.player, Fixtures.status(&"strength"), -10)
	check_eq(DamageCalc.attack_damage(6, combat.player, enemy), 0, "negative Strength floors at 0")


func test_block_absorbs_attack() -> void:
	var combat := Fixtures.combat([Fixtures.attacker_enemy(8)])
	combat.start()
	var defend := Fixtures.give(combat, &"warden_defend")
	combat.play_card(defend)
	check_eq(combat.player.block, 5, "Defend grants 5 Block")
	combat.end_player_turn()
	check_eq(combat.player.hp, 77, "8 damage - 5 Block = 3 HP lost")


func test_poison_ignores_block() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	combat.gain_block(combat.player, 10)
	combat.deal_damage(combat.enemies[0], combat.player, 5, DamageInfo.Type.POISON)
	check_eq(combat.player.hp, 75, "poison damage bypasses Block")
	check_eq(combat.player.block, 10, "Block untouched")


func test_poison_ticks_and_decays() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	var enemy := combat.enemies[0]
	combat.apply_status(enemy, Fixtures.status(&"poison"), 4)
	combat.end_player_turn()
	check_eq(enemy.hp, 96, "loses 4 at the start of its turn")
	check_eq(enemy.get_stacks(&"poison"), 3, "then decays by 1")


func test_burn_ticks_and_halves() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	var enemy := combat.enemies[0]
	combat.apply_status(enemy, Fixtures.status(&"burn"), 5)
	combat.end_player_turn()
	check_eq(enemy.hp, 95, "takes 5 at end of its turn")
	check_eq(enemy.get_stacks(&"burn"), 2, "5 halves to 2")
	combat.end_player_turn()
	check_eq(enemy.hp, 93, "takes 2")
	combat.end_player_turn()
	check_eq(enemy.hp, 92, "takes 1")
	check(not enemy.has_status(&"burn"), "1 halves to 0 and is removed")


func test_thorns_reflect_attacks() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	combat.apply_status(combat.enemies[0], Fixtures.status(&"thorns"), 3)
	combat.play_card(Fixtures.give(combat, &"warden_strike"), combat.enemies[0])
	check_eq(combat.player.hp, 77, "3 Thorns damage back")
	check_eq(combat.enemies[0].hp, 94, "strike still lands")


func test_frail_reduces_block() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	combat.apply_status(combat.player, Fixtures.status(&"frail"), 1)
	combat.play_card(Fixtures.give(combat, &"warden_defend"))
	check_eq(combat.player.block, 3, "5 x0.75 floors to 3")


func test_dexterity_adds_block() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	combat.apply_status(combat.player, Fixtures.status(&"dexterity"), 2)
	combat.play_card(Fixtures.give(combat, &"warden_defend"))
	check_eq(combat.player.block, 7, "5 + 2 Dexterity")
