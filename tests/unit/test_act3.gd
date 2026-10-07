extends TestCase


func _enemy(id: StringName) -> EnemyData:
	return ContentDB.get_enemy(id)


func test_void_leech_lifesteal() -> void:
	var combat := Fixtures.combat([_enemy(&"void_leech")])
	combat.start()
	var leech := combat.enemies[0]
	combat.deal_damage(combat.player, leech, 20, DamageInfo.Type.OTHER)
	var hurt := leech.hp
	var drain := DealDamageEffect.new()
	drain.amount = 9
	drain.lifesteal = true
	drain.execute(EffectContext.new(combat, leech, combat.player))
	check_eq(leech.hp, hurt + 9, "heals for the unblocked damage")


func test_weaver_rewinds_hp() -> void:
	var combat := Fixtures.combat([_enemy(&"astral_weaver")])
	combat.start()
	var weaver := combat.enemies[0]
	var full := weaver.hp
	combat.end_player_turn()  # its turn 1: Thread (history = [full])
	combat.deal_damage(combat.player, weaver, 15, DamageInfo.Type.OTHER)
	combat.end_player_turn()  # turn 2: Loom
	combat.deal_damage(combat.player, weaver, 10, DamageInfo.Type.OTHER)
	combat.end_player_turn()  # turn 3: Rewind to its HP two turns earlier
	check_eq(weaver.hp, full, "back to the HP it had on its first turn")


func test_harpy_airborne_halves_then_grounds() -> void:
	var combat := Fixtures.combat([_enemy(&"storm_harpy")])
	combat.start()
	var harpy := combat.enemies[0]
	var before := harpy.hp
	combat.deal_damage(combat.player, harpy, 10, DamageInfo.Type.ATTACK)
	check_eq(before - harpy.hp, 5, "Airborne: half damage")
	combat.deal_damage(combat.player, harpy, 10, DamageInfo.Type.ATTACK)
	combat.deal_damage(combat.player, harpy, 10, DamageInfo.Type.ATTACK)
	combat._flush()
	check(not harpy.has_status(&"airborne"), "three hits ground it")
	before = harpy.hp
	combat.deal_damage(combat.player, harpy, 10, DamageInfo.Type.ATTACK)
	check_eq(before - harpy.hp, 10, "full damage once grounded")


func test_seraph_halo_drops_with_fragments() -> void:
	var enc := ContentDB.get_encounter(&"a3_starfall_seraph")
	var combat := Fixtures.combat(enc.enemies)
	combat.start()
	var seraph := combat.enemies[0]
	check_eq(seraph.get_stacks(&"halo"), 3, "one Halo stack per fragment")
	var before := seraph.hp
	combat.deal_damage(combat.player, seraph, 20, DamageInfo.Type.ATTACK)
	check_eq(before - seraph.hp, 5, "75% less damage under Halo")
	for i in range(1, 4):
		combat.deal_damage(combat.player, combat.enemies[i], 99, DamageInfo.Type.OTHER)
	combat._flush()
	check(not seraph.has_status(&"halo"), "Halo gone once every fragment falls")


func test_orrery_supernova_countdown() -> void:
	var combat := Fixtures.combat([_enemy(&"the_orrery")])
	combat.start()
	var orrery := combat.enemies[0]
	combat.deal_damage(combat.player, orrery, orrery.hp - int(orrery.max_hp * 0.3), DamageInfo.Type.OTHER)
	check_eq(orrery.phase_index, 2, "jumps to the Supernova phase")
	check_eq(orrery.get_stacks(&"supernova"), 6, "countdown starts at 6")
	combat.end_player_turn()
	check_eq(orrery.get_stacks(&"supernova"), 5, "counts down each of its turns")


func test_gravity_punishes_full_hands() -> void:
	var combat := Fixtures.combat([Fixtures.dummy_enemy(100)])
	combat.start()
	combat.apply_status(combat.player, ContentDB.get_status(&"gravity"), 1)
	var hand := combat.hand.size()
	var hp := combat.player.hp
	combat.end_player_turn()
	check_eq(combat.player.hp, hp - 2 * hand, "2 HP per card left in hand")


func test_final_act_is_three() -> void:
	check_eq(GameManager.FINAL_ACT, 3, "the run ends after the Act 3 boss")
	check(not ContentDB.get_encounters(3, EncounterData.Pool.BOSS).is_empty(), "Act 3 has a boss")
