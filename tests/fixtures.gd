class_name Fixtures
extends RefCounted
## Helpers for building combats in tests and simulations from real content.


static func warden() -> CharacterClassData:
	return ContentDB.get_character_class(&"pyre_warden")


static func card(id: StringName, upgraded := false) -> CardInstance:
	var data := ContentDB.get_card(id)
	assert(data != null, "unknown card " + id)
	return CardInstance.new(data, upgraded)


static func status(id: StringName) -> StatusEffectData:
	return ContentDB.get_status(id)


## An enemy that does nothing (keeps tests free of enemy noise).
static func dummy_enemy(hp := 100, display := "Dummy") -> EnemyData:
	var e := EnemyData.new()
	e.id = &"dummy"
	e.display_name = display
	e.hp_min = hp
	e.hp_max = hp
	var wait := EnemyMoveData.new()
	wait.id = &"wait"
	wait.intent = EnemyMoveData.Intent.BUFF
	var phase := EnemyPhaseData.new()
	phase.moves.assign([wait])
	e.phases.assign([phase])
	return e


## An enemy that attacks for [param damage] every turn.
static func attacker_enemy(damage: int, hp := 100) -> EnemyData:
	var e := dummy_enemy(hp, "Attacker")
	var hit := DealDamageEffect.new()
	hit.amount = damage
	var attack := EnemyMoveData.new()
	attack.id = &"hit"
	attack.intent = EnemyMoveData.Intent.ATTACK
	attack.effects.assign([hit])
	e.phases[0].moves.assign([attack])
	return e


static func encounter(enemies: Array) -> EncounterData:
	var enc := EncounterData.new()
	enc.id = &"test"
	enc.enemies.assign(enemies)
	return enc


## Builds (but doesn't start) a combat. [param deck_ids] defaults to the
## Warden starter deck; [param with_relic] adds Cinder Heart.
static func combat(enemies: Array, deck_ids: Array = [], with_relic := false, seed_value := 1, hp := 80) -> CombatState:
	var cls := warden()
	var deck: Array[CardInstance] = []
	if deck_ids.is_empty():
		for data in cls.starting_deck:
			deck.append(CardInstance.new(data))
	else:
		for id in deck_ids:
			deck.append(card(id))
	var relics: Array[RelicData] = []
	if with_relic:
		relics.append(cls.starting_relic)
	return CombatState.create(cls, deck, hp, cls.max_hp, relics, encounter(enemies), 0, RngStreams.new(seed_value))


## Puts a specific card in hand (bypassing the draw pile).
static func give(combat_state: CombatState, id: StringName, upgraded := false) -> CardInstance:
	var c := card(id, upgraded)
	combat_state.hand.append(c)
	return c


## A Moonblade combat with its starter deck (and Moonsilver Locket if asked).
static func moonblade_combat(enemies: Array, with_relic := false, seed_value := 1) -> CombatState:
	var cls := ContentDB.get_character_class(&"moonblade")
	var deck: Array[CardInstance] = []
	for data in cls.starting_deck:
		deck.append(CardInstance.new(data))
	var relics: Array[RelicData] = []
	if with_relic:
		relics.append(cls.starting_relic)
	return CombatState.create(cls, deck, cls.max_hp, cls.max_hp, relics, encounter(enemies), 0, RngStreams.new(seed_value))
