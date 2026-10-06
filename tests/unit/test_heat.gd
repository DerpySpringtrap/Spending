extends TestCase


func test_kindle_stokes() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	combat.play_card(Fixtures.give(combat, &"kindle"), combat.enemies[0])
	check_eq(combat.player.resource_value, 2, "Stoke 2")
	check_eq(combat.enemies[0].hp, 93, "7 damage")


func test_vent_pays_for_bonus_only_when_affordable() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100), Fixtures.dummy_enemy(100)])
	combat.start()
	combat.set_class_resource(2)
	combat.play_card(Fixtures.give(combat, &"vent_flame"))
	check_eq(combat.player.resource_value, 2, "can't afford Vent 3: heat kept")
	check(not combat.enemies[0].has_status(&"burn"), "no bonus")
	check_eq(combat.enemies[1].hp, 95, "base AoE still hits")
	combat.set_class_resource(3)
	combat.play_card(Fixtures.give(combat, &"vent_flame"))
	check_eq(combat.player.resource_value, 0, "Vent spent 3")
	check_eq(combat.enemies[0].get_stacks(&"burn"), 3, "bonus Burn on enemy 1")
	check_eq(combat.enemies[1].get_stacks(&"burn"), 3, "bonus Burn on enemy 2")


func test_overheat_at_end_of_turn() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	combat.set_class_resource(10)
	combat.end_player_turn()
	check_eq(combat.enemies[0].hp, 88, "Overheat blasts 12")
	check_eq(combat.player.hp, 77, "3 recoil")
	check_eq(combat.player.resource_value, 0, "heat reset")


func test_no_overheat_below_max() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	combat.set_class_resource(9)
	combat.end_player_turn()
	check_eq(combat.enemies[0].hp, 100, "no blast")
	check_eq(combat.player.resource_value, 9, "heat persists between turns")


func test_eternal_pyre_changes_overheat() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	combat.player.energy = 3
	combat.play_card(Fixtures.give(combat, &"eternal_pyre"))
	combat.set_class_resource(10)
	combat.end_player_turn()
	check_eq(combat.player.hp, 80, "no recoil")
	check_eq(combat.player.resource_value, 5, "resets to 5")


func test_cinder_heart_starting_heat() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)], [], true)
	combat.start()
	check_eq(combat.player.resource_value, 3, "relic grants 3 Heat at combat start")


func test_supernova_scales_with_vented_heat() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100), Fixtures.dummy_enemy(100)])
	combat.start()
	combat.set_class_resource(5)
	var nova := Fixtures.give(combat, &"supernova")
	check(CardText.render(nova, combat).contains("20"), "preview shows 4 x 5 Heat = 20")
	combat.play_card(nova)
	check_eq(combat.enemies[0].hp, 80, "20 damage")
	check_eq(combat.enemies[1].hp, 80, "AoE")
	check_eq(combat.player.resource_value, 0, "all heat vented")


func test_molten_bastion() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	combat.set_class_resource(4)
	combat.play_card(Fixtures.give(combat, &"molten_bastion"))
	check_eq(combat.player.block, 8, "2 per Heat")
	check_eq(combat.player.resource_value, 4, "doesn't spend heat")
	check(combat.player.has_status(&"ember_shell"), "block will be retained")


func test_searing_aegis_burns_attackers_only_when_blocking() -> void:
	var combat := Fixtures.combat([Fixtures.attacker_enemy(3)])
	combat.start()
	var enemy := combat.enemies[0]
	combat.apply_status(combat.player, Fixtures.status(&"searing_aegis"), 2)
	combat.end_player_turn()
	check(not enemy.has_status(&"burn"), "no Block, no Burn")
	combat.gain_block(combat.player, 5)
	combat.end_player_turn()
	# Burn 2 applied on hit, then ticks at the end of the enemy's own turn.
	check_eq(enemy.hp, 98, "burned for 2")
	check_eq(enemy.get_stacks(&"burn"), 1, "halved to 1")


func test_wildfire_spreads_burn() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100), Fixtures.dummy_enemy(100), Fixtures.dummy_enemy(100)])
	combat.start()
	combat.apply_status(combat.enemies[1], Fixtures.status(&"burn"), 6)
	var wildfire := Fixtures.give(combat, &"wildfire")
	combat.play_card(wildfire, combat.enemies[1])
	check_eq(combat.enemies[0].get_stacks(&"burn"), 6, "spread to enemy 1")
	check_eq(combat.enemies[2].get_stacks(&"burn"), 6, "spread to enemy 3")
	check_eq(combat.enemies[1].get_stacks(&"burn"), 6, "origin unchanged")
	check(combat.exhaust_pile.has(wildfire), "exhausts")


func test_card_text_live_numbers() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	var strike := Fixtures.give(combat, &"warden_strike")
	check_eq(CardText.render(strike), "Deal 6 damage.", "base text")
	combat.apply_status(combat.player, Fixtures.status(&"strength"), 2)
	check_eq(CardText.render(strike, combat), "Deal 8 damage.", "Strength shown live")
	combat.apply_status(combat.enemies[0], Fixtures.status(&"vulnerable"), 1)
	check_eq(CardText.render(strike, combat, combat.enemies[0]), "Deal 12 damage.", "hovered target's Vulnerable shown")
	check_eq(CardText.render(strike, combat, null, true), "Deal [color=%s]8[/color] damage." % CardText.COLOR_UP, "BBCode colouring")
	check_eq(CardText.render(Fixtures.card(&"warden_strike", true)), "Deal 9 damage.", "upgraded")
