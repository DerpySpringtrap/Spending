extends TestCase


func test_final_map_is_rest_shop_elite_boss() -> void:
	var map := MapGenerator.generate_final(4)
	var types := []
	var current := ""
	for i in 4:
		var next := MapGenerator.reachable(map, current)
		check_eq(next.size(), 1, "a single path")
		current = next[0]
		types.append(map.nodes[current].type)
	check_eq(types, [MapGenerator.TYPE_REST, MapGenerator.TYPE_SHOP, MapGenerator.TYPE_ELITE, MapGenerator.TYPE_BOSS], "rest, shop, elite, boss")


func test_act4_unlocks_after_first_act3_win() -> void:
	var backup := MetaProgress.to_dict()
	MetaProgress.from_dict({})
	check_eq(GameManager.final_act(), 3, "locked: the run ends after Act 3")
	var result := MetaProgress.record_run(&"pyre_warden", true, 48, 0, 10, true, true, true)
	check(MetaProgress.act4_unlocked, "beating Act 3 unlocks Act 4")
	check(result.unlocks.any(func(u): return String(u).begins_with("Act 4")), "the summary says so")
	check_eq(GameManager.final_act(), 4, "new runs go on to Act 4")
	RunState.start(Fixtures.warden(), 0, 3)
	check_eq(RunState.final_act, 4, "fixed on the run at start")
	RunState.act = 3
	RunLogic.advance_act()
	check_eq(RunState.map_data.nodes.size(), 4, "Act 4 uses the short final map")
	RunState.clear()
	MetaProgress.from_dict(backup)
	MetaProgress.save_meta()


func test_umbra_meter_bursts_and_resets() -> void:
	var combat := Fixtures.combat([ContentDB.get_enemy(&"umbral_sovereign")])
	combat.start()
	var boss := combat.enemies[0]
	var before := combat.player.hp
	for i in 6:  # Heat caps at 10, so alternate gaining and spending: 12 events.
		combat.change_class_resource(1)
		combat.change_class_resource(-1)
	combat._flush()
	check_eq(boss.get_stacks(&"umbra"), 0, "meter reset after Total Darkness")
	check(combat.player.hp <= before - 20, "Total Darkness hit hard")


func test_corona_destroys_summons() -> void:
	var combat := Fixtures.class_combat(&"rootmother", [ContentDB.get_enemy(&"umbral_sovereign")], true)
	combat.start()
	check_eq(combat.living_summons().size(), 1, "a Sproutling from the Seed")
	var boss := combat.enemies[0]
	combat.deal_damage(combat.player, boss, boss.hp - int(boss.max_hp * 0.2), DamageInfo.Type.OTHER)
	check_eq(boss.phase_index, 2, "Corona phase")
	check(combat.living_summons().is_empty(), "entering Corona destroys your summons")
