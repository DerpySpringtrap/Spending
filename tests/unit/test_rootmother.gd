extends TestCase


func _root(enemies: Array, with_relic := false) -> CombatState:
	return Fixtures.class_combat(&"rootmother", enemies, with_relic)


func test_seed_summons_a_sproutling() -> void:
	var combat := _root([Fixtures.dummy_enemy(100)], true)
	combat.start()
	check_eq(combat.living_summons().size(), 1, "Seed of the First Tree summons at combat start")
	check_eq(combat.summons[0].data.id, &"sproutling", "a Sproutling")


func test_front_summon_soaks_single_target_attacks() -> void:
	var combat := _root([Fixtures.attacker_enemy(5, 100)])
	combat.start()
	combat.player.energy = 10
	combat.play_card(Fixtures.give(combat, &"sow_barkguard"))
	var guard := combat.summons[0]
	var player_hp := combat.player.hp
	combat.end_player_turn()
	check_eq(combat.player.hp, player_hp, "the player took nothing")
	check(guard.hp < 8 or guard.block < 3, "the Barkguard took the hit")


func test_overflow_carries_through_when_a_summon_dies() -> void:
	var combat := _root([Fixtures.attacker_enemy(30, 100)])
	combat.start()
	combat.player.energy = 10
	combat.play_card(Fixtures.give(combat, &"sow_thornling"))
	var player_hp := combat.player.hp
	combat.end_player_turn()
	check(combat.summons[0].is_dead, "the Thornling (3 HP) died")
	check_eq(combat.player.hp, player_hp - 27, "the other 27 damage carries through")


func test_summons_act_at_end_of_turn() -> void:
	var combat := _root([Fixtures.dummy_enemy(100)])
	combat.start()
	combat.player.energy = 10
	combat.play_card(Fixtures.give(combat, &"sow_thornling"))
	var enemy_hp := combat.enemies[0].hp
	combat.end_player_turn()
	check_eq(combat.enemies[0].hp, enemy_hp - 2, "Thornling hits the front enemy for 2")


func test_max_three_and_sap_per_summon() -> void:
	var combat := _root([Fixtures.dummy_enemy(200)])
	combat.start()
	combat.player.energy = 20
	for i in 4:
		combat.play_card(Fixtures.give(combat, &"sow_sproutling"))
	check_eq(combat.living_summons().size(), 3, "capped at 3")
	var sap := combat.player.resource_value
	combat.end_player_turn()
	check_eq(combat.player.resource_value, sap + 3, "1 Sap per living summon at turn start")


func test_scaling_and_aoe_reach_summons() -> void:
	var combat := _root([Fixtures.dummy_enemy(200)])
	combat.start()
	combat.player.energy = 20
	combat.play_card(Fixtures.give(combat, &"sow_sproutling"))
	combat.play_card(Fixtures.give(combat, &"sow_sproutling"))
	var hp := combat.enemies[0].hp
	combat.play_card(Fixtures.give(combat, &"chorus_of_leaves"), combat.enemies[0])
	check_eq(hp - combat.enemies[0].hp, 4 + 8, "4 + 4 per summon")
	var everyone := combat.living_opponents_of(combat.enemies[0])
	check_eq(everyone.size(), 3, "enemy AoE hits the player and both summons")


func test_elder_treant_sacrifice() -> void:
	var combat := _root([Fixtures.dummy_enemy(200)])
	combat.start()
	combat.player.energy = 20
	combat.play_card(Fixtures.give(combat, &"sow_sproutling"))
	combat.play_card(Fixtures.give(combat, &"sow_sproutling"))
	combat.play_card(Fixtures.give(combat, &"elder_treant"))
	var living := combat.living_summons()
	check_eq(living.size(), 1, "only the Treant remains")
	check_eq(living[0].data.id, &"elder_treant", "it's the Elder Treant")
	check_eq(living[0].max_hp, 10 + 2 * 5, "+5 max HP per sacrificed summon")
	check(living[0].has_status(&"taunt"), "it Taunts")


func test_mycelial_network_poisons_on_summon_hit() -> void:
	var combat := _root([Fixtures.dummy_enemy(200)])
	combat.start()
	combat.player.energy = 20
	combat.play_card(Fixtures.give(combat, &"mycelial_network"))
	combat.play_card(Fixtures.give(combat, &"sow_thornling"))
	var hp := combat.enemies[0].hp
	combat.end_player_turn()
	check_eq(hp - combat.enemies[0].hp, 2 + 1, "Thornling hit (2) applied 1 Poison, which ticked on the enemy's turn")
