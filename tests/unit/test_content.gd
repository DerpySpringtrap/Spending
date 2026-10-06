extends TestCase
## Validates authored content so broken .tres files fail CI, not playtests.


func test_card_tokens_resolve() -> void:
	for card: CardData in ContentDB.cards.values():
		var keys := CardText.collect_keys(card)
		for template in [card.description, card.upgraded_description]:
			for token in CardText.find_tokens(template):
				check(keys.has(token), "%s: {%s} has no effect with that value_key" % [card.id, token])


func test_all_cards_render() -> void:
	for card: CardData in ContentDB.cards.values():
		for upgraded in [false, true]:
			var text := CardText.render(CardInstance.new(card, upgraded))
			check(not text.contains("{"), "%s renders without leftover tokens: %s" % [card.id, text])


func test_untargeted_cards_dont_hit_chosen() -> void:
	# CHOSEN falls back to the player when a card has no target: an untargeted
	# card with a CHOSEN attack would hit yourself.
	for card: CardData in ContentDB.cards.values():
		if card.target_mode == CardData.TargetMode.SINGLE_ENEMY:
			continue
		var effects: Array[GameEffect] = card.effects.duplicate()
		var i := 0
		while i < effects.size():
			effects.append_array(effects[i].get_sub_effects())
			i += 1
		for effect in effects:
			var hostile := effect is DealDamageEffect or effect is SpreadStatusEffect
			check(not (hostile and effect.target == GameEffect.Target.CHOSEN),
					"%s has no target but an effect targets CHOSEN" % card.id)


func test_ids_match_file_names() -> void:
	for card: CardData in ContentDB.cards.values():
		check_eq(card.resource_path.get_file().get_basename(), String(card.id), "card file name matches id")
	for enemy: EnemyData in ContentDB.enemies.values():
		check_eq(enemy.resource_path.get_file().get_basename(), String(enemy.id), "enemy file name matches id")


func test_enemies_have_moves() -> void:
	for enemy: EnemyData in ContentDB.enemies.values():
		check(not enemy.phases.is_empty(), "%s has a phase" % enemy.id)
		for phase in enemy.phases:
			check(not phase.moves.is_empty(), "%s phase has moves" % enemy.id)
			for move in phase.moves:
				check(move.id != &"", "%s has a move without id" % enemy.id)


func test_warden_class() -> void:
	var cls := ContentDB.get_character_class(&"pyre_warden")
	check(cls != null, "Pyre Warden exists")
	check_eq(cls.starting_deck.size(), 10, "10-card starting deck")
	check(cls.starting_relic != null, "starting relic")
	check(cls.secondary_resource != null and cls.secondary_resource.id == &"heat", "Heat resource")


func test_statuses_described() -> void:
	for status: StatusEffectData in ContentDB.statuses.values():
		check(not status.display_name.is_empty() and not status.description.is_empty(), "%s has name and description" % status.id)
