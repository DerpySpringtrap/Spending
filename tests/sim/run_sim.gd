extends Node
## Headless full-run simulator: plays complete runs (every act) with simple policies
## (GreedyPlayerAI in combat, heuristic choices elsewhere). Catches crashes in
## the run loop and gives a first read on difficulty.
##
## godot --headless --path . res://tests/sim/run_sim.tscn -- --runs=200 --class=moonblade --ascension=0

var _class_id: StringName = &"pyre_warden"
var _runs := 200
var _ascension := 0
var _ai := GreedyPlayerAI.new()
var _deaths := {}
var _wins := 0
var _floors := 0
var _errors := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=")
		if parts.size() == 2:
			match parts[0]:
				"runs": _runs = int(parts[1])
				"ascension": _ascension = int(parts[1])
				"class": _class_id = StringName(parts[1])
				"unlock-all": MetaProgress.unlock_all = parts[1] == "1"
	var started := Time.get_ticks_msec()
	var final_hp_total := 0
	var deck_sizes := 0
	for i in _runs:
		var result := _play_run(1000 + i)
		_floors += result.floor
		if result.won:
			_wins += 1
			final_hp_total += result.hp
			deck_sizes += result.deck
		else:
			_deaths[result.killer] = _deaths.get(result.killer, 0) + 1
	print("\nRun simulator: %d runs, A%d, %.1fs" % [_runs, _ascension, (Time.get_ticks_msec() - started) / 1000.0])
	print("Win rate: %.1f%%   Avg floor reached: %.1f   Avg HP left on wins: %.0f   Avg deck size on wins: %.1f" % [
		100.0 * _wins / _runs, float(_floors) / _runs, float(final_hp_total) / maxi(_wins, 1), float(deck_sizes) / maxi(_wins, 1)])
	var killers := _deaths.keys()
	killers.sort_custom(func(a, b): return _deaths[a] > _deaths[b])
	for k in killers:
		print("  died to %-24s %d" % [k, _deaths[k]])
	print("RUN SIM: %s" % ("PASS" if _errors == 0 else "FAIL (%d errors)" % _errors))
	RunState.clear()
	get_tree().quit(1 if _errors > 0 else 0)


func _play_run(seed_value: int) -> Dictionary:
	RunState.start(ContentDB.get_character_class(_class_id), _ascension, seed_value)
	RunState.map_data = MapGenerator.generate(RunState.rng.get_stream(&"map"), 1, _ascension)
	var guard := 0
	while guard < 40 * GameManager.FINAL_ACT:
		guard += 1
		var options := MapGenerator.reachable(RunState.map_data, RunState.current_node)
		if options.is_empty():
			_errors += 1
			push_error("run %d: no reachable nodes from %s" % [seed_value, RunState.current_node])
			return {"won": false, "floor": RunState.total_floor(), "killer": "<stuck>", "hp": 0, "deck": 0}
		var node_id := _choose_node(options)
		RunState.current_node = node_id
		var node := RunState.current_map_node()
		RunState.floor_number = int(node.floor) + 1
		var type: String = node.type
		match type:
			MapGenerator.TYPE_MONSTER, MapGenerator.TYPE_ELITE, MapGenerator.TYPE_BOSS:
				var enc := RunLogic.pick_encounter(type)
				if not _fight(enc):
					return {"won": false, "floor": RunState.total_floor(), "killer": String(enc.id), "hp": 0, "deck": 0}
				if type == MapGenerator.TYPE_BOSS:
					if RunState.act >= GameManager.FINAL_ACT:
						return {"won": true, "floor": RunState.total_floor(), "killer": "", "hp": RunState.hp, "deck": RunState.deck.size()}
					_take_rewards(RunLogic.combat_rewards(type))
					RunLogic.advance_act()
					continue
				if type == MapGenerator.TYPE_MONSTER:
					RunState.monster_fights += 1
				_take_rewards(RunLogic.combat_rewards(type))
			MapGenerator.TYPE_REST:
				_rest()
			MapGenerator.TYPE_SHOP:
				_shop()
			MapGenerator.TYPE_TREASURE:
				_take_rewards(RunLogic.treasure_rewards())
			MapGenerator.TYPE_EVENT:
				if not _event():
					return {"won": false, "floor": RunState.total_floor(), "killer": "event fight", "hp": 0, "deck": 0}
	_errors += 1
	return {"won": false, "floor": RunState.total_floor(), "killer": "<loop>", "hp": 0, "deck": 0}


func _choose_node(options: Array[String]) -> String:
	# Prefer elites when healthy, rests when hurt, otherwise anything but elites.
	var hp_ratio := float(RunState.hp) / RunState.max_hp
	var best := options[0]
	var best_score := -999.0
	for id in options:
		var t: String = RunState.map_data.nodes[id].type
		var score := RunState.rng.get_stream(&"misc").randf()
		match t:
			MapGenerator.TYPE_ELITE: score += 2.0 if hp_ratio > 0.7 else -3.0
			MapGenerator.TYPE_REST: score += 3.0 if hp_ratio < 0.5 else 0.0
			MapGenerator.TYPE_SHOP: score += 1.0 if RunState.gold > 150 else 0.0
			MapGenerator.TYPE_EVENT: score += 0.5
		if score > best_score:
			best_score = score
			best = id
	return best


func _fight(enc: EncounterData) -> bool:
	var combat := CombatState.create(RunState.get_class_data(), RunState.deck, RunState.hp, RunState.max_hp,
			RunState.relics, enc, RunState.ascension, RunState.rng)
	combat.player_gold = RunState.gold
	combat.start()
	if enc.pool == EncounterData.Pool.ELITE or enc.pool == EncounterData.Pool.BOSS:
		_ai.use_all_potions(combat, RunState.potions)
	while not combat.is_over():
		_ai.play_turn(combat)
	RunState.add_gold(combat.player_gold - RunState.gold)
	if combat.result == CombatState.Result.VICTORY:
		RunState.set_hp(combat.player.hp)
		return true
	if not combat.player.is_dead:
		_errors += 1
		push_error("combat %s timed out (deck: %s | draw %d hand %d discard %d exhausted %d)" % [enc.id,
			", ".join(RunState.deck.map(func(c): return c.get_display_name())), combat.draw_pile.size(), combat.hand.size(),
			combat.discard_pile.size(), combat.exhaust_pile.size()])
	return false


func _take_rewards(rewards: Array[Dictionary]) -> void:
	for r in rewards:
		match r.type:
			"gold": RunState.add_gold(r.amount)
			"relic": RunState.add_relic(r.relic)
			"relic_choice": RunState.add_relic(r.choices[0])
			"potion": RunState.add_potion(r.potion)
			"card":
				if RunState.deck.size() < 22 and not r.choices.is_empty():
					var pick: CardData = r.choices[0]
					for c in r.choices:
						if c.rarity > pick.rarity:
							pick = c
					RunState.add_card(pick)


func _rest() -> void:
	if RunState.hp < RunState.max_hp * 0.6:
		RunState.heal(RunLogic.rest_heal_amount())
	else:
		_upgrade_random()


func _upgrade_random() -> void:
	var options := RunState.deck.filter(func(c): return c.can_upgrade())
	if not options.is_empty():
		RunState.upgrade_card(RunState.rng.pick(options, &"misc"))


func _remove_worst() -> void:
	for c in RunState.deck:
		if c.data.type == CardData.CardType.CURSE or c.data.id == &"warden_strike":
			RunState.remove_card(c)
			return


func _shop() -> void:
	var stock := RunLogic.shop_stock()
	if RunState.gold >= stock.removal_price:
		RunState.add_gold(-stock.removal_price)
		RunState.removals += 1
		_remove_worst()
	for entry in stock.cards:
		if RunState.gold >= entry.price and entry.card.rarity != CardData.Rarity.COMMON:
			RunState.add_gold(-entry.price)
			RunState.add_card(entry.card)
			break


func _event() -> bool:
	var ev := RunLogic.pick_event()
	if ev == null:
		return true
	var choices := ev.choices.filter(func(c): return RunLogic.choice_available(c) == "")
	if choices.is_empty():
		return true
	RunState.rng.shuffle(choices, &"misc")
	for c in choices:
		for o in c.outcomes:
			match RunLogic.apply_outcome(o):
				"remove": _remove_worst()
				"upgrade": _upgrade_random()
				"fight":
					if not _fight(o.encounter):
						return false
					_take_rewards(RunLogic.combat_rewards(MapGenerator.TYPE_MONSTER, true))
		return true
	return true
