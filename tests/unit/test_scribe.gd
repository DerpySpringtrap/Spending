extends TestCase


func _scribe(with_relic := false) -> CombatState:
	return Fixtures.class_combat(&"hollow_scribe", [Fixtures.dummy_enemy(200)], with_relic)


func test_footnote_and_ink_on_manual_discard() -> void:
	var combat := _scribe()
	combat.start()
	var note := Fixtures.give(combat, &"marginalia")
	combat.discard_card(note)
	combat._flush()
	check_eq(combat.player.block, 4, "Footnote: gain 4 Block")
	check_eq(combat.player.resource_value, 3 + 1, "starts at 2, +1 at turn start, +1 for the manual discard")


func test_end_of_turn_discard_is_not_manual() -> void:
	var combat := _scribe()
	combat.start()
	var before := combat.player.resource_value
	combat.end_player_turn()
	check_eq(combat.player.resource_value, before + 1, "only the turn-start Ink, nothing from the end-of-turn discard")


func test_erase_gains_ink() -> void:
	var combat := _scribe()
	combat.start()
	var before := combat.player.resource_value
	combat.exhaust_card(combat.hand[0])
	combat._flush()
	check_eq(combat.player.resource_value, before + 1, "Erase gains 1 Ink")


func test_inscribe_and_living_manuscript_discount() -> void:
	var combat := _scribe()
	combat.start()
	combat.player.energy = 10
	var enemy := combat.enemies[0]
	combat.set_class_resource(1)
	combat.play_card(Fixtures.give(combat, &"quill_jab"), enemy)
	check_eq(enemy.hp, 193, "can't pay Inscribe 2 with 1 Ink: base hit only")
	combat.play_card(Fixtures.give(combat, &"living_manuscript"))
	combat.play_card(Fixtures.give(combat, &"quill_jab"), enemy)
	check_eq(enemy.hp, 179, "Living Manuscript makes Inscribe 2 cost 1")
	check_eq(combat.player.resource_value, 0, "Ink spent")


func test_interactive_choice_pauses_and_resumes() -> void:
	var combat := _scribe()
	combat.interactive = true
	combat.start()
	combat.player.energy = 10
	var redact := Fixtures.give(combat, &"redact")
	var victim := combat.hand[0]
	var hand_before := combat.hand.size()
	var ink_before := combat.player.resource_value
	combat.play_card(redact)
	check(not combat.pending_choice.is_empty(), "waits for the player")
	check_eq(combat.can_play(combat.hand[0]), "Choose cards first", "no other plays meanwhile")
	check(not combat.resolve_choice([]), "must choose exactly one")
	check(combat.resolve_choice([victim]), "valid choice accepted")
	check(combat.exhaust_pile.has(victim), "chosen card Erased")
	check_eq(combat.player.resource_value, ink_before + 1 + 2, "1 Ink for the Erase, 2 from Redact's text (after the choice)")
	check_eq(combat.hand.size(), hand_before - 2 + 1, "Redact and the victim gone, then draw 1")


func test_revision_draws_that_many() -> void:
	var combat := _scribe()
	combat.interactive = true
	combat.start()
	combat.player.energy = 10
	combat.play_card(Fixtures.give(combat, &"revision"))
	var picks := [combat.hand[0], combat.hand[1]]
	var size_before := combat.hand.size()
	var ink_before := combat.player.resource_value
	combat.resolve_choice(picks)
	check_eq(combat.hand.size(), size_before, "discarded 2, drew 2")
	check_eq(combat.player.resource_value, ink_before + 2, "1 Ink per discarded card")


func test_auto_choice_when_not_interactive() -> void:
	var combat := _scribe()
	combat.start()
	combat.player.energy = 10
	combat.play_card(Fixtures.give(combat, &"blot"))
	check(combat.pending_choice.is_empty(), "AI/sim mode resolves at once")
	check_eq(combat.discard_pile.size(), 2, "Blot itself plus the discarded card")


func test_dog_eared_tome_first_turn() -> void:
	var combat := _scribe(true)
	combat.interactive = true
	combat.start()
	check(not combat.pending_choice.is_empty(), "Tome asks on turn 1")
	var pick: CardInstance = combat.pending_choice.options[0]
	combat.resolve_choice([pick])
	check(combat.hand.has(pick), "card moved to hand")
	check_eq(combat.hand.size(), 6, "5 drawn + 1 chosen")


func test_bind_the_curse() -> void:
	var combat := _scribe()
	combat.start()
	combat.player.energy = 10
	combat.set_class_resource(0)
	var ink_before := 0
	combat.add_card_to_pile(ContentDB.get_card(&"muck"), CombatState.Pile.HAND)
	combat.add_card_to_pile(ContentDB.get_card(&"guilt"), CombatState.Pile.HAND)
	combat.play_card(Fixtures.give(combat, &"bind_the_curse"))
	combat._flush()
	check_eq(combat.player.block, 10, "5 Block per card")
	check_eq(combat.player.resource_value, ink_before + 3 * 2 + 2, "3 Ink each + 1 per Erase")
