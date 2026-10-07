extends TestCase
## Co-op fights: one PlayerSeat per hero, party-wide enemy attacks, enemy HP
## scaled by party size, simultaneous turns.


func _thief(amount: int, hp := 100) -> EnemyData:
	var e := Fixtures.dummy_enemy(hp, "Thief")
	var take := StealGoldEffect.new()
	take.amount = amount
	var move := EnemyMoveData.new()
	move.id = &"pilfer"
	move.intent = EnemyMoveData.Intent.DEBUFF
	move.effects.assign([take])
	e.phases[0].moves.assign([move])
	return e


## Attacks for [param damage] and gains [param block] Block in the same move.
func _brute(damage: int, block: int, hp := 100) -> EnemyData:
	var e := Fixtures.attacker_enemy(damage, hp)
	var guard := GainBlockEffect.new()
	guard.amount = block
	guard.target = GameEffect.Target.SELF
	e.phases[0].moves[0].effects.append(guard)
	return e


func test_enemy_hp_scales_with_party_size() -> void:
	var solo := Fixtures.class_combat(&"pyre_warden", [Fixtures.dummy_enemy(40)])
	var duo := Fixtures.party_combat([&"pyre_warden", &"moonblade"], [Fixtures.dummy_enemy(40)])
	var trio := Fixtures.party_combat([&"pyre_warden", &"moonblade", &"rootmother"], [Fixtures.dummy_enemy(40)])
	check_eq(solo.enemies[0].max_hp, 40, "solo: base HP")
	check_eq(duo.enemies[0].max_hp, 80, "two heroes: double HP")
	check_eq(trio.enemies[0].max_hp, 120, "three heroes: triple HP")


func test_each_hero_has_their_own_hand_and_energy() -> void:
	var combat := Fixtures.party_combat([&"pyre_warden", &"moonblade"], [Fixtures.dummy_enemy(100)])
	combat.start()
	check_eq(combat.seats[0].hand.size(), 5, "hero 1 drew 5")
	check_eq(combat.seats[1].hand.size(), 5, "hero 2 drew 5")
	check(combat.seats[0].hand[0] != combat.seats[1].hand[0], "different cards")
	combat.use_seat(1)
	var strike: CardInstance = null
	for card in combat.hand:
		if card.data.type == CardData.CardType.ATTACK:
			strike = card
			break
	check(strike != null, "hero 2 has an attack")
	check(combat.play_card(strike, combat.enemies[0]), "hero 2 plays it")
	check_eq(combat.seats[1].player.energy, 2, "hero 2 spent 1 energy")
	check_eq(combat.seats[0].player.energy, 3, "hero 1's energy is untouched")
	check_eq(combat.seats[0].hand.size(), 5, "hero 1's hand is untouched")


func test_enemy_phase_waits_for_every_hero() -> void:
	var combat := Fixtures.party_combat([&"pyre_warden", &"moonblade"], [Fixtures.attacker_enemy(6, 100)])
	combat.start()
	combat.use_seat(0)
	combat.end_player_turn()
	check_eq(combat.round_number, 1, "still round 1 while hero 2 plays")
	check(combat.seats[0].ended_turn, "hero 1 is marked ready")
	check(combat.can_play(combat.hand[0]) != "", "a ready hero can't play more cards")
	combat.use_seat(1)
	combat.end_player_turn()
	combat.use_seat(0)
	check_eq(combat.round_number, 2, "both ready: the enemies acted and round 2 began")
	check(not combat.seats[0].ended_turn and not combat.seats[1].ended_turn, "everyone can act again")


func test_enemy_attack_hits_every_hero() -> void:
	var combat := Fixtures.party_combat([&"pyre_warden", &"moonblade"], [Fixtures.attacker_enemy(12, 100)])
	combat.start()
	var hp0 := combat.seats[0].player.hp
	var hp1 := combat.seats[1].player.hp
	for i in 2:
		combat.use_seat(i)
		combat.end_player_turn()
	check_eq(combat.seats[0].player.hp, hp0 - 12, "hero 1 took 12")
	check_eq(combat.seats[1].player.hp, hp1 - 12, "hero 2 also took 12")


func test_each_heros_block_protects_only_them() -> void:
	var combat := Fixtures.party_combat([&"pyre_warden", &"moonblade"], [Fixtures.attacker_enemy(12, 100)])
	combat.start()
	combat.use_seat(0)
	combat.gain_block(combat.player, 20)
	var hp0 := combat.seats[0].player.hp
	var hp1 := combat.seats[1].player.hp
	for i in 2:
		combat.use_seat(i)
		combat.end_player_turn()
	check_eq(combat.seats[0].player.hp, hp0, "hero 1 blocked it all")
	check_eq(combat.seats[1].player.hp, hp1 - 12, "hero 2 still took 12")


func test_enemy_self_buffs_happen_once() -> void:
	var combat := Fixtures.party_combat([&"pyre_warden", &"moonblade"], [_brute(5, 7, 100)])
	combat.start()
	for i in 2:
		combat.use_seat(i)
		combat.end_player_turn()
	check_eq(combat.enemies[0].block, 7, "the enemy gained its Block once, not once per hero")


func test_summons_only_guard_their_own_hero() -> void:
	var combat := Fixtures.party_combat([&"pyre_warden", &"rootmother"], [Fixtures.attacker_enemy(5, 100)])
	combat.start()
	combat.use_seat(1)
	combat.player.energy = 10
	combat.play_card(Fixtures.give(combat, &"sow_barkguard"))
	check_eq(combat.seats[1].summons.size(), 1, "the Barkguard joins the Rootmother's seat")
	check_eq(combat.seats[0].summons.size(), 0, "not the Warden's")
	var hp0 := combat.seats[0].player.hp
	var hp1 := combat.seats[1].player.hp
	for i in 2:
		combat.use_seat(i)
		combat.end_player_turn()
	check_eq(combat.seats[1].player.hp, hp1, "the Rootmother is guarded")
	check_eq(combat.seats[0].player.hp, hp0 - 5, "the Warden takes the hit")


func test_thieves_rob_each_hero_and_return_it() -> void:
	var combat := Fixtures.party_combat([&"pyre_warden", &"moonblade"], [_thief(15, 30)])
	combat.start()
	for i in 2:
		combat.use_seat(i)
		combat.end_player_turn()
	check_eq(combat.seats[0].player_gold, 85, "hero 1 lost 15 gold")
	check_eq(combat.seats[1].player_gold, 85, "hero 2 lost 15 gold")
	combat.use_seat(0)
	combat.deal_damage(combat.player, combat.enemies[0], 999, DamageInfo.Type.OTHER)
	check_eq(combat.seats[0].player_gold, 100, "hero 1 got theirs back")
	check_eq(combat.seats[1].player_gold, 100, "hero 2 got theirs back")


func test_a_fallen_hero_does_not_end_the_fight() -> void:
	var combat := Fixtures.party_combat([&"pyre_warden", &"moonblade"], [Fixtures.attacker_enemy(5, 100)])
	combat.start()
	combat.use_seat(1)
	combat.deal_damage(null, combat.player, 999, DamageInfo.Type.HP_LOSS)
	check(combat.seats[1].player.is_dead, "hero 2 fell")
	check(not combat.is_over(), "the fight goes on")
	combat.use_seat(0)
	var round_before := combat.round_number
	combat.end_player_turn()
	check_eq(combat.round_number, round_before + 1, "the survivor alone ends the turn")
	combat.deal_damage(null, combat.player, 999, DamageInfo.Type.HP_LOSS)
	check(combat.is_over() and combat.result == CombatState.Result.DEFEAT, "everyone down: defeat")


func test_hero_dying_on_their_own_turn_unblocks_the_party() -> void:
	var combat := Fixtures.party_combat([&"pyre_warden", &"moonblade"], [Fixtures.dummy_enemy(100)])
	combat.start()
	combat.use_seat(0)
	combat.end_player_turn()
	combat.use_seat(1)
	combat.player.hp = 1
	var round_before := combat.round_number
	# Something during hero 2's own command kills them (as a self-damage card would).
	combat.deal_damage(null, combat.player, 5, DamageInfo.Type.HP_LOSS)
	combat._after_command()
	combat.use_seat(0)
	check_eq(combat.round_number, round_before + 1, "the turn moved on without the fallen hero")


func test_only_the_home_hero_drives_hand_signals() -> void:
	var combat := Fixtures.party_combat([&"pyre_warden", &"moonblade"], [Fixtures.dummy_enemy(100)])
	combat.home_seat = 1
	combat.use_seat(1)
	var drawn := [0]
	var updates := [0]
	var on_draw := func(_card): drawn[0] += 1
	var on_update := func(_seat): updates[0] += 1
	EventBus.card_drawn.connect(on_draw)
	EventBus.seat_updated.connect(on_update)
	combat.start()
	EventBus.card_drawn.disconnect(on_draw)
	EventBus.seat_updated.disconnect(on_update)
	check_eq(drawn[0], 5, "only the home hero's 5 draws are announced")
	check(updates[0] >= 1, "the other hero's changes arrive as seat updates")


func test_same_commands_same_result() -> void:
	var a := _scripted_fight(7)
	var b := _scripted_fight(7)
	check_eq(a, b, "identical seeds and commands give identical fights (lockstep)")


func _scripted_fight(seed_value: int) -> String:
	var combat := Fixtures.party_combat([&"hollow_scribe", &"rootmother"],
			[Fixtures.attacker_enemy(7, 60), Fixtures.attacker_enemy(4, 40)], true, seed_value)
	combat.start()
	for round in 4:
		for i in 2:
			combat.use_seat(i)
			for k in 3:
				if combat.hand.is_empty() or combat.is_over():
					break
				var card := combat.hand[0]
				var target: Combatant = combat.living_enemies()[0] if not combat.living_enemies().is_empty() else null
				if combat.can_play(card, target) == "":
					combat.play_card(card, target)
				if not combat.pending_choice.is_empty():
					combat.resolve_choice(combat.pending_choice.options.slice(0, combat.pending_choice.min))
			combat.end_player_turn()
		if combat.is_over():
			break
	var parts: PackedStringArray = []
	for s in combat.seats:
		parts.append("%d/%d/%d/%d" % [s.player.hp, s.hand.size(), s.draw_pile.size(), s.player.resource_value])
	for e in combat.enemies:
		parts.append("%d/%d" % [e.hp, e.block])
	return ",".join(parts)
