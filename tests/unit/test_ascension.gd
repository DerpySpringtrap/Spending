extends TestCase


func _combat_at(enc_id: StringName, asc: int) -> CombatState:
	var cls := Fixtures.warden()
	var deck: Array[CardInstance] = []
	for d in cls.starting_deck:
		deck.append(CardInstance.new(d))
	var relics: Array[RelicData] = []
	return CombatState.create(cls, deck, 80, 85, relics, ContentDB.get_encounter(enc_id), asc, RngStreams.new(4))


func _has_affix(enemy: Combatant) -> bool:
	for id in AscensionRules.ELITE_AFFIXES:
		if enemy.has_status(id):
			return true
	return false


func test_a8_elites_get_an_affix() -> void:
	var low := _combat_at(&"a1_gorehorn_bull", 7)
	low.start()
	check(not _has_affix(low.enemies[0]), "no affix below A8")
	var high := _combat_at(&"a1_gorehorn_bull", 8)
	high.start()
	check(_has_affix(high.enemies[0]), "an affix at A8")


func test_vampiric_heals() -> void:
	var combat := Fixtures.combat([Fixtures.attacker_enemy(10, 100)])
	combat.start()
	var enemy := combat.enemies[0]
	combat.deal_damage(combat.player, enemy, 20, DamageInfo.Type.OTHER)
	combat.apply_status(enemy, ContentDB.get_status(&"affix_vampiric"), 1)
	var hurt := enemy.hp
	combat.end_player_turn()
	check_eq(enemy.hp, hurt + 5, "heals half of the 10 HP its attack dealt")


func test_a12_halves_upgraded_rewards() -> void:
	RunState.start(Fixtures.warden(), 0, 1)
	RunState.act = 3
	var normal := RunLogic.upgrade_chance()
	RunState.ascension = 12
	check_eq(RunLogic.upgrade_chance(), normal * 0.5, "half as likely at A12")
	RunState.act = 1
	check_eq(RunLogic.upgrade_chance(), 0.0, "none in Act 1")
	RunState.clear()


func test_a15_boss_tricks() -> void:
	var matriarch := _combat_at(&"a1_drowned_matriarch", 15)
	check_eq(matriarch.enemies.size(), 4, "the Matriarch brings an extra Broodling")
	var hierophant := _combat_at(&"a2_gilded_hierophant", 15)
	hierophant.start()
	check(hierophant.enemies[1].has_status(&"reassemble"), "Gold Idols revive once")
	var below := _combat_at(&"a2_gilded_hierophant", 14)
	below.start()
	check(not below.enemies[1].has_status(&"reassemble"), "only at A15")
