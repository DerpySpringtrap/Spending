extends TestCase


func _stance_id(combat: CombatState) -> StringName:
	return combat.player.stance.id if combat.player.stance else &""


func test_wax_wane_shift_and_charge() -> void:
	var combat := Fixtures.moonblade_combat([Fixtures.dummy_enemy(200)])
	combat.start()
	combat.player.energy = 10
	var step := Fixtures.give(combat, &"moonstep")
	combat.play_card(step)
	check_eq(_stance_id(combat), &"waxing", "Shift from no phase enters Waxing")
	check_eq(combat.player.resource_value, 1, "phase change grants 1 Lunar Charge")
	var parry := Fixtures.give(combat, &"tidal_parry")
	combat.play_card(parry)
	check_eq(_stance_id(combat), &"waning", "Wane")
	check(not combat.player.has_status(&"waxing"), "old phase removed")
	check_eq(combat.player.block, 8, "Waning adds 2 Block to the card's own Block")
	var parry2 := Fixtures.give(combat, &"tidal_parry")
	combat.play_card(parry2)
	check_eq(combat.player.resource_value, 2, "re-entering the same phase is not a change")
	check_eq(combat.stance_changes_this_turn, 2, "two changes counted")


func test_waxing_adds_damage_per_hit() -> void:
	var combat := Fixtures.moonblade_combat([Fixtures.dummy_enemy(200)])
	combat.start()
	combat.player.energy = 10
	var enemy := combat.enemies[0]
	combat.play_card(Fixtures.give(combat, &"twin_crescents"), enemy)
	check_eq(enemy.hp, 200 - 2 * (4 + 2), "Wax first, then two hits of 4+2")


func test_waning_riposte() -> void:
	var combat := Fixtures.moonblade_combat([Fixtures.attacker_enemy(5, 100)])
	combat.start()
	combat.player.energy = 10
	combat.play_card(Fixtures.give(combat, &"tidal_parry"))
	combat.end_player_turn()
	check_eq(combat.enemies[0].hp, 98, "Riposte deals 2 when attacked")


func test_eclipse_at_full_charge() -> void:
	var combat := Fixtures.moonblade_combat([Fixtures.dummy_enemy(200)])
	combat.start()
	combat.player.energy = 10
	combat.set_class_resource(4)
	var hand_before := combat.hand.size()
	var step := Fixtures.give(combat, &"moonstep")
	combat.play_card(step)
	check_eq(_stance_id(combat), &"eclipse", "changing at 4 charges enters Eclipse")
	check(combat.has_status_or_stance(combat.player, &"waxing"), "Eclipse counts as Waxing")
	check(combat.has_status_or_stance(combat.player, &"waning"), "Eclipse counts as Waning")
	check_eq(combat.hand.size(), hand_before + 2, "Eclipse draws 2")
	combat.play_card(Fixtures.give(combat, &"tidal_parry"))
	check_eq(_stance_id(combat), &"eclipse", "phase cards don't leave Eclipse")
	combat.end_player_turn()
	check_eq(_stance_id(combat), &"", "Eclipse ends at end of turn")
	check_eq(combat.player.resource_value, 0, "Lunar Charge resets")


func test_total_eclipse() -> void:
	var combat := Fixtures.moonblade_combat([Fixtures.dummy_enemy(200)])
	combat.start()
	combat.player.energy = 10
	combat.play_card(Fixtures.give(combat, &"total_eclipse"))
	check_eq(_stance_id(combat), &"eclipse", "enters Eclipse directly")


func test_moonfall_cost_drops() -> void:
	var combat := Fixtures.moonblade_combat([Fixtures.dummy_enemy(200)])
	combat.start()
	combat.player.energy = 10
	var moonfall := Fixtures.give(combat, &"moonfall")
	check_eq(moonfall.get_cost(), 3, "base cost")
	combat.play_card(Fixtures.give(combat, &"moonstep"))
	combat.play_card(Fixtures.give(combat, &"moonstep"))
	check_eq(moonfall.get_cost(), 1, "-1 per phase change")
	combat.end_player_turn()
	check_eq(moonfall.get_cost(), 3, "resets next turn")


func test_locket_draws_once_per_turn() -> void:
	var combat := Fixtures.moonblade_combat([Fixtures.dummy_enemy(200)], true)
	combat.start()
	combat.player.energy = 10
	var before := combat.hand.size()
	combat.play_card(Fixtures.give(combat, &"riptide"))
	check_eq(combat.hand.size(), before + 1, "first change draws 1")
	combat.play_card(Fixtures.give(combat, &"riptide"))
	check_eq(combat.hand.size(), before + 1, "second change doesn't")


func test_conditional_and_scaled_zero() -> void:
	var combat := Fixtures.moonblade_combat([Fixtures.dummy_enemy(200)])
	combat.start()
	combat.player.energy = 10
	var enemy := combat.enemies[0]
	combat.play_card(Fixtures.give(combat, &"phase_cut"), enemy)
	check_eq(enemy.hp, 195, "no phase changes: the scaled bonus hit doesn't happen")
	var before := combat.hand.size()
	combat.play_card(Fixtures.give(combat, &"silver_lunge"), enemy)
	check_eq(combat.hand.size(), before, "not in Waxing: no draw")
	combat.play_card(Fixtures.give(combat, &"crescent_cut"), enemy)
	before = combat.hand.size()
	combat.play_card(Fixtures.give(combat, &"silver_lunge"), enemy)
	check_eq(combat.hand.size(), before + 1, "in Waxing: draws 1")


func test_silver_reflection_requires_waning() -> void:
	var combat := Fixtures.moonblade_combat([Fixtures.attacker_enemy(5, 100)])
	combat.start()
	combat.player.energy = 10
	combat.play_card(Fixtures.give(combat, &"silver_reflection"))
	combat.end_player_turn()
	check_eq(combat.enemies[0].hp, 100, "no Riposte outside Waning")
	combat.player.energy = 10
	combat.play_card(Fixtures.give(combat, &"tidal_parry"))
	combat.end_player_turn()
	check_eq(combat.enemies[0].hp, 95, "Riposte 2 + Silver Reflection 3")
