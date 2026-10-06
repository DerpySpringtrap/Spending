extends TestCase
## The Drowned Matriarch: brood shelter, summons and the phase change.


func _boss_fight() -> CombatState:
	var enc := ContentDB.get_encounter(&"a1_drowned_matriarch")
	var deck: Array[CardInstance] = []
	for data in Fixtures.warden().starting_deck:
		deck.append(CardInstance.new(data))
	var relics: Array[RelicData] = []
	return CombatState.create(Fixtures.warden(), deck, 80, 80, relics, enc, 0, RngStreams.new(5))


func _matriarch(combat: CombatState) -> EnemyCombatant:
	for e in combat.enemies:
		if e.data.id == &"drowned_matriarch":
			return e
	return null


func test_brood_mother_block_scales_with_toads() -> void:
	var combat := _boss_fight()
	combat.start()
	var boss := _matriarch(combat)
	boss.next_move = null
	combat.end_player_turn()
	check_eq(boss.block, 10, "5 Block per living Broodling (2)")


func test_phase_two_cleanses_and_sequences() -> void:
	var combat := _boss_fight()
	combat.start()
	var boss := _matriarch(combat)
	combat.apply_status(boss, Fixtures.status(&"weak"), 2)
	combat.deal_damage(combat.player, boss, boss.hp - boss.max_hp / 2 + 1, DamageInfo.Type.OTHER)
	check_eq(boss.phase_index, 1, "entered phase 2 at half HP")
	check(not boss.has_status(&"weak"), "debuffs cleansed")
	check_eq(boss.get_stacks(&"strength"), 2, "gained 2 Strength")
	check_eq(boss.next_move.id, &"whirlpool", "phase 2 starts its sequence")


func test_call_the_brood_only_without_toads() -> void:
	var combat := _boss_fight()
	combat.start()
	var boss := _matriarch(combat)
	var rng := RandomNumberGenerator.new()
	for i in 50:
		var move := EnemyAI.choose_by_rules(boss, rng, 2)
		check(move.id != &"call_the_brood", "no summoning while toads live")
	var summoned := false
	for i in 50:
		if EnemyAI.choose_by_rules(boss, rng, 0).id == &"call_the_brood":
			summoned = true
	check(summoned, "summons once the brood is dead")
