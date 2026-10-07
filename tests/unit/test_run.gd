extends TestCase
## Map generation, rewards, shop and event rules.


func before_each() -> void:
	RunState.start(Fixtures.warden(), 0, 99)


func test_map_structure_rules() -> void:
	for seed_value in 40:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var map := MapGenerator.generate(rng)
		var boss: String = map.boss
		for id in map.nodes:
			var node: Dictionary = map.nodes[id]
			var f := int(node.floor)
			if f == 0:
				check_eq(node.type, MapGenerator.TYPE_MONSTER, "floor 1 is all fights")
			elif f == 8:
				check_eq(node.type, MapGenerator.TYPE_TREASURE, "floor 9 is treasure")
			elif f == 14:
				check_eq(node.type, MapGenerator.TYPE_REST, "floor 15 is rest")
			if f < 5:
				check(node.type != MapGenerator.TYPE_ELITE and node.type != MapGenerator.TYPE_REST, "no early elites/rests (seed %d)" % seed_value)
			if id != boss:
				check(not node.next.is_empty(), "every node leads somewhere (seed %d, %s)" % [seed_value, id])
			for next_id in node.next:
				check_eq(int(map.nodes[next_id].floor), f + 1, "edges go up one floor")
		check(_reaches_boss(map), "every start reaches the boss (seed %d)" % seed_value)
		check(MapGenerator.reachable(map, "").size() >= 2, "at least two starting nodes")


func _reaches_boss(map: Dictionary) -> bool:
	for start in MapGenerator.reachable(map, ""):
		var frontier: Array = [start]
		var found := false
		while not frontier.is_empty():
			var id: String = frontier.pop_back()
			if id == map.boss:
				found = true
				break
			frontier.append_array(map.nodes[id].next)
		if not found:
			return false
	return true


func test_map_survives_save_load() -> void:
	RunState.map_data = MapGenerator.generate(RunState.rng.get_stream(&"map"))
	var start: String = MapGenerator.reachable(RunState.map_data, "")[0]
	RunState.current_node = start
	RunState.save_run()
	var expected := MapGenerator.reachable(RunState.map_data, start)
	check(RunState.load_run(), "loads")
	check_eq(RunState.current_node, start, "current node restored")
	check_eq(MapGenerator.reachable(RunState.map_data, RunState.current_node), expected, "reachable nodes identical after JSON round trip")
	RunState.clear()


func test_combat_rewards() -> void:
	var rewards := RunLogic.combat_rewards(MapGenerator.TYPE_MONSTER)
	var types := rewards.map(func(r): return r.type)
	check(types.has("gold") and types.has("card"), "monster: gold + card")
	for r in rewards:
		if r.type == "card":
			check_eq(r.choices.size(), 3, "three card choices")
			var ids := {}
			for c in r.choices:
				ids[c.id] = true
				check(c.rarity != CardData.Rarity.STARTER, "no starter cards in rewards")
			check_eq(ids.size(), 3, "choices are distinct")
	var elite := RunLogic.combat_rewards(MapGenerator.TYPE_ELITE)
	check(elite.map(func(r): return r.type).has("relic"), "elites drop a relic")


func test_relics_not_duplicated() -> void:
	for i in 30:
		var relic := RunLogic.roll_relic()
		if relic == null:
			break
		check(not RunState.has_relic(relic.id), "rolled relic not already owned")
		RunState.add_relic(relic)
	check(RunState.relics.size() > 5, "several relics available")


func test_shop_stock() -> void:
	var stock := RunLogic.shop_stock()
	check_eq(stock.cards.size(), 7, "seven cards")
	check(stock.relics.size() >= 1, "relics on sale")
	check_eq(stock.removal_price, 75, "first removal costs 75")
	var on_sale: Array = stock.cards.filter(func(c): return c.get("sale", false))
	check_eq(on_sale.size(), 1, "one card on sale")


func test_event_outcomes() -> void:
	RunState.set_hp(40)
	var heal := EventOutcome.new()
	heal.type = EventOutcome.Type.HEAL
	heal.amount = 25
	heal.percent = true
	RunLogic.apply_outcome(heal)
	check_eq(RunState.hp, 61, "25% of 85 max HP")
	var lose := EventOutcome.new()
	lose.type = EventOutcome.Type.LOSE_GOLD
	lose.amount = 500
	RunLogic.apply_outcome(lose)
	check_eq(RunState.gold, 0, "gold floors at 0")
	var remove := EventOutcome.new()
	remove.type = EventOutcome.Type.REMOVE_CARD
	check_eq(RunLogic.apply_outcome(remove), "remove", "card removal needs a pick")


func test_events_are_valid() -> void:
	for ev: EventData in ContentDB.events.values():
		check(not ev.choices.is_empty(), "%s has choices" % ev.id)
		for c in ev.choices:
			for o in c.outcomes:
				if o.type == EventOutcome.Type.FIGHT:
					check(o.encounter != null, "%s fight has an encounter" % ev.id)
				if o.type == EventOutcome.Type.GAIN_CARD:
					check(o.card != null, "%s card outcome has a card" % ev.id)


func test_every_pool_has_encounters() -> void:
	for pool in [EncounterData.Pool.EASY, EncounterData.Pool.HARD, EncounterData.Pool.ELITE, EncounterData.Pool.BOSS]:
		check(not ContentDB.get_encounters(1, pool).is_empty(), "act 1 pool %s has encounters" % EncounterData.Pool.keys()[pool])
