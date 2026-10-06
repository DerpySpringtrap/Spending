extends TestCase
## Meta-progression. Restores the player's real meta save afterwards.

var _backup: Dictionary


func _snapshot() -> void:
	_backup = MetaProgress.to_dict()
	MetaProgress.from_dict({})


func _restore() -> void:
	MetaProgress.from_dict(_backup)
	MetaProgress.save_meta()


func test_levels_from_xp() -> void:
	check_eq(MetaProgress.level_for_xp(0), 1, "level 1 at 0 XP")
	check_eq(MetaProgress.level_for_xp(MetaProgress.LEVEL_XP[1]), 2, "level 2 at its threshold")
	check_eq(MetaProgress.level_for_xp(99999), MetaProgress.max_level(), "capped at max level")
	check_eq(MetaProgress.level_bounds(99999).y, -1, "no next level at max")


func test_locked_cards_leave_the_pool() -> void:
	_snapshot()
	var rares := ContentDB.get_reward_pool(&"moonblade", CardData.Rarity.RARE).map(func(c): return c.id)
	check(not rares.has(&"starfall"), "level-4 card locked at level 1")
	check(rares.has(&"moonfall"), "base card available")
	MetaProgress.class_xp[&"moonblade"] = MetaProgress.LEVEL_XP[3]
	rares = ContentDB.get_reward_pool(&"moonblade", CardData.Rarity.RARE).map(func(c): return c.id)
	check(rares.has(&"starfall"), "unlocked at level 4")
	var relics := ContentDB.get_relics_by_rarity(RelicData.Rarity.COMMON, &"moonblade").map(func(r): return r.id)
	check(relics.has(&"tidal_charm"), "class relic unlocked by level 3")
	_restore()


func test_first_run_unlocks_moonblade() -> void:
	_snapshot()
	check(not MetaProgress.is_class_unlocked(&"moonblade"), "locked on a fresh save")
	var result := MetaProgress.record_run(&"pyre_warden", false, 8, 0, 80)
	check(MetaProgress.is_class_unlocked(&"moonblade"), "unlocked after any run")
	check_eq(result.new_level, 2, "80 XP reaches level 2")
	check(result.unlocks.size() >= 2, "summary lists the level-up and the new class")
	result = MetaProgress.record_run(&"pyre_warden", true, 32, 0, 10)
	check_eq(MetaProgress.get_max_ascension(&"pyre_warden"), 1, "a win unlocks the next ascension")
	_restore()


func test_unlock_all() -> void:
	_snapshot()
	MetaProgress.unlock_all = true
	check(MetaProgress.is_class_unlocked(&"moonblade"), "every class")
	check(ContentDB.get_reward_pool(&"pyre_warden", CardData.Rarity.RARE).map(func(c): return c.id).has(&"eternal_pyre"), "every card")
	_restore()


func test_ascension_map_and_hp() -> void:
	var elites := [0, 0]
	for i in 30:
		for a in 2:
			var map := MapGenerator.generate(RngStreams.new(500 + i).get_stream(&"map"), 1, a)
			for id in map.nodes:
				if map.nodes[id].type == MapGenerator.TYPE_ELITE:
					elites[a] += 1
	check(elites[1] > elites[0], "A1 maps have more elites (%d vs %d)" % [elites[1], elites[0]])
	RunState.start(Fixtures.warden(), 14, 1)
	check_eq(RunState.max_hp, Fixtures.warden().max_hp - 5, "A14: -5 max HP")
	RunState.clear()
