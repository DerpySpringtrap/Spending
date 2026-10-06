extends TestCase


func _enemy(id: StringName) -> EnemyData:
	return ContentDB.get_enemy(id)


func test_skeleton_reassembles_once() -> void:
	var combat := Fixtures.combat([_enemy(&"gilded_skeleton"), Fixtures.dummy_enemy(100)])
	combat.start()
	var skel := combat.enemies[0]
	combat.deal_damage(combat.player, skel, 999, DamageInfo.Type.OTHER)
	check(not skel.is_dead, "revives while an ally stands")
	check_eq(skel.hp, ceili(skel.max_hp * 0.5), "at 50% HP")
	check(skel.skips_turn(), "stunned for a turn")
	check(not skel.has_status(&"reassemble"), "only once")
	combat.deal_damage(combat.player, skel, 999, DamageInfo.Type.OTHER)
	check(skel.is_dead, "second death sticks")


func test_skeleton_alone_stays_dead() -> void:
	var combat := Fixtures.combat([_enemy(&"gilded_skeleton")])
	combat.start()
	combat.deal_damage(combat.player, combat.enemies[0], 999, DamageInfo.Type.OTHER)
	check(combat.enemies[0].is_dead, "no revive when it's the last enemy")
	check_eq(combat.result, CombatState.Result.VICTORY, "fight won")


func test_mimic_steals_and_returns_gold() -> void:
	var combat := Fixtures.combat([_enemy(&"coin_mimic")])
	combat.player_gold = 20
	combat.start()
	var mimic := combat.enemies[0]
	check_eq(combat.steal_gold(mimic, 15), 15, "steals 15")
	check_eq(combat.steal_gold(mimic, 15), 5, "can't take more than you have")
	check_eq(combat.player_gold, 0, "purse empty")
	combat.deal_damage(combat.player, mimic, 999, DamageInfo.Type.OTHER)
	check_eq(combat.player_gold, 20, "killing it returns the gold")


func test_mimic_escapes_with_gold() -> void:
	var combat := Fixtures.combat([_enemy(&"coin_mimic")])
	combat.player_gold = 100
	combat.start()
	for i in 4:
		combat.end_player_turn()
	check(combat.enemies[0].escaped, "flees on its 4th turn")
	check_eq(combat.result, CombatState.Result.VICTORY, "fight ends when the last enemy flees")
	check_eq(combat.player_gold, 70, "two Pilfers of 15 are gone")


func test_gilded_plate_strips_on_hp_loss() -> void:
	var combat := Fixtures.combat([_enemy(&"gilded_knight")])
	combat.start()
	var knight := combat.enemies[0]
	check_eq(knight.get_stacks(&"gilded_plate"), 8, "starts with 8")
	combat.deal_damage(combat.player, knight, 3, DamageInfo.Type.ATTACK)
	combat.deal_damage(combat.player, knight, 3, DamageInfo.Type.ATTACK)
	check_eq(knight.get_stacks(&"gilded_plate"), 6, "each wounding hit strips one")


func test_hound_pack_tactics() -> void:
	var combat := Fixtures.combat([_enemy(&"crypt_hound"), _enemy(&"crypt_hound")])
	combat.start()
	combat.deal_damage(combat.player, combat.enemies[0], 999, DamageInfo.Type.OTHER)
	combat._flush()
	check_eq(combat.enemies[1].get_stacks(&"strength"), 2, "survivor gains Strength")


func test_act_advance_and_boss_relic_choice() -> void:
	RunState.start(Fixtures.warden(), 0, 99)
	RunState.map_data = MapGenerator.generate(RunState.rng.get_stream(&"map"), 1)
	RunState.set_hp(20)
	var rewards := RunLogic.combat_rewards(MapGenerator.TYPE_BOSS)
	var choice: Array = rewards.filter(func(r): return r.type == "relic_choice")
	check_eq(choice.size(), 1, "boss rewards offer a relic choice")
	check_eq(choice[0].choices.size(), 3, "of three boss relics")
	RunLogic.advance_act()
	check_eq(RunState.act, 2, "act 2")
	check_eq(RunState.hp, 20 + ceili((RunState.max_hp - 20) * 0.75), "heals 75% of missing HP")
	check_eq(RunState.current_node, "", "back at the start of a new map")
	check(not MapGenerator.reachable(RunState.map_data, "").is_empty(), "new map is walkable")
	check_eq(RunLogic.pick_encounter(MapGenerator.TYPE_MONSTER).act, 2, "act 2 encounters")
	RunState.clear()
