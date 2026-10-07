class_name CombatState
extends RefCounted
## The rules of one fight: turn order, energy, piles, damage, statuses,
## triggers and enemy intents.
##
## Pure logic with no Nodes and no waiting. Every public call resolves fully and
## synchronously, emitting EventBus signals as it goes; the presentation layer
## (Milestone 2) replays those signals as animation beats. This keeps combat
## deterministic, unit-testable and fast enough for headless balance sims.
##
## Usage:
##   var combat := CombatState.create(class_data, deck, hp, max_hp, relics, encounter, ascension, rng)
##   combat.start()
##   combat.play_card(card, target)
##   combat.end_player_turn()   # runs the enemy phase and starts the next player turn
##
## Co-op: create_party() builds one PlayerSeat per hero. The player/hand/pile
## fields below read the *active* seat; every command runs with the acting
## hero's seat active (use_seat), and triggers switch to their owner's seat
## while they resolve. Enemy effects aimed at "the player" run once per living
## hero, so a 12-damage attack deals 12 to each of them. Enemy HP is multiplied
## by the number of heroes. Heroes play at the same time; the enemy phase runs
## once every living hero has ended their turn. Signals about hands, piles,
## energy and the class resource are only emitted for [member home_seat] (the
## hero this screen shows); other heroes' changes emit EventBus.seat_updated.

enum Phase { NOT_STARTED, PLAYER_TURN, ENEMY_TURN, ENDED }
enum Result { NONE, VICTORY, DEFEAT }
enum Pile { DRAW, HAND, DISCARD, EXHAUST }

## Safety net for simulations with degenerate decks.
const ROUND_LIMIT := 100
const MAX_BLOCK := 999

const MAX_SUMMONS := 3

## One per hero (solo = one). [member seat] is the one being acted for.
var seats: Array[PlayerSeat] = []
var seat: PlayerSeat
## The hero this client shows and controls (co-op); 0 in solo.
var home_seat: int = 0
var enemies: Array[EnemyCombatant] = []
var encounter: EncounterData

# The active seat's fields, kept under their solo names.
var player: PlayerCombatant:
	get: return seat.player
	set(value): seat.player = value
## The active hero's allies (Rootmother). Dead ones stay in the list.
var summons: Array[SummonCombatant]:
	get: return seat.summons
	set(value): seat.summons = value
var draw_pile: Array[CardInstance]:  ## Top of the pile is the END of the array.
	get: return seat.draw_pile
	set(value): seat.draw_pile = value
var hand: Array[CardInstance]:
	get: return seat.hand
	set(value): seat.hand = value
var discard_pile: Array[CardInstance]:
	get: return seat.discard_pile
	set(value): seat.discard_pile = value
var exhaust_pile: Array[CardInstance]:
	get: return seat.exhaust_pile
	set(value): seat.exhaust_pile = value
var relics: Array[RelicData]:
	get: return seat.relics
	set(value): seat.relics = value
var cards_played_this_turn: int:
	get: return seat.cards_played_this_turn
	set(value): seat.cards_played_this_turn = value
## The run's gold, mirrored so thieves know how much they can take. The combat
## screen applies EventBus.gold_stolen to RunState as it happens.
var player_gold: int:
	get: return seat.player_gold
	set(value): seat.player_gold = value
var stance_changes_this_turn: int:
	get: return seat.stance_changes_this_turn
	set(value): seat.stance_changes_this_turn = value
## The choice the active hero still has to make, or {} (see request_choice).
var pending_choice: Dictionary:
	get: return seat.pending_choice
	set(value): seat.pending_choice = value

var ascension: int = 0
var rng: RngStreams

var round_number: int = 0
var phase: Phase = Phase.NOT_STARTED
var result: Result = Result.NONE

var queue := ActionQueue.new()
var _trigger_counts: Dictionary = {}  # "<owner id>:<trigger instance id>" -> int
var _once_per_turn_fired: Dictionary = {}  # same keys; cleared each player turn

## True when a person is choosing (the combat screen sets it). Otherwise card
## choices resolve at once through [member auto_choose].
var interactive := false
## Callable(options: Array[CardInstance], min_count: int, max_count: int,
## mode: ChooseCardsEffect.Mode) -> Array. Null = CombatState.default_choice.
var auto_choose: Callable
var _ending := false


static func create(
		class_data: CharacterClassData,
		deck: Array[CardInstance],
		hp: int,
		max_hp: int,
		p_relics: Array[RelicData],
		p_encounter: EncounterData,
		p_ascension: int,
		p_rng: RngStreams) -> CombatState:
	return create_party([{"class_data": class_data, "deck": deck, "hp": hp, "max_hp": max_hp, "relics": p_relics}],
			p_encounter, p_ascension, p_rng)


## A fight for several heroes. Each entry of [param heroes]:
## {"class_data", "deck": Array[CardInstance], "hp", "max_hp", "relics": Array[RelicData], "gold" (optional)}.
static func create_party(heroes: Array, p_encounter: EncounterData, p_ascension: int, p_rng: RngStreams) -> CombatState:
	var combat := CombatState.new()
	for i in heroes.size():
		var hero: Dictionary = heroes[i]
		var s := PlayerSeat.new(i, PlayerCombatant.new(hero.class_data, hero.hp, hero.max_hp))
		var hero_relics: Array = hero.get("relics", [])
		s.relics.assign(hero_relics)
		for card in hero.deck:
			s.draw_pile.append(card.clone_for_combat())
		s.player_gold = int(hero.get("gold", 0))
		combat.seats.append(s)
	combat.seat = combat.seats[0]
	combat.encounter = p_encounter
	combat.ascension = p_ascension
	combat.rng = p_rng
	for enemy_data in p_encounter.enemies:
		combat.add_enemy(enemy_data)
	if p_ascension >= 15:
		for enemy_data in p_encounter.a15_extra_enemies:
			combat.add_enemy(enemy_data)
	return combat


## Adds an enemy (encounter setup or mid-fight summons). Returns it.
func add_enemy(enemy_data: EnemyData) -> EnemyCombatant:
	var hp := enemy_data.roll_hp(rng.get_stream(&"combat"))
	hp = ceili(hp * AscensionRules.enemy_hp_multiplier(enemy_data.tier, ascension)) * seats.size()
	var enemy := EnemyCombatant.new(enemy_data, hp)
	enemies.append(enemy)
	if phase != Phase.NOT_STARTED:
		EventBus.combatant_spawned.emit(enemy)
		_apply_starting_statuses(enemy)
		_roll_intent(enemy)
	return enemy


# =============================================================================
# Seats (co-op)
# =============================================================================

func party_size() -> int:
	return seats.size()


func is_coop() -> bool:
	return seats.size() > 1


## Makes [param index] the hero being acted for (commands from the network or
## the local player). Callers restore [member home_seat] afterwards.
func use_seat(index: int) -> void:
	seat = seats[clampi(index, 0, seats.size() - 1)]


## The seat a player-side combatant belongs to (the hero or one of its summons).
func seat_of(combatant: Combatant) -> PlayerSeat:
	if combatant is PlayerCombatant:
		return seats[combatant.seat_index]
	if combatant is SummonCombatant:
		return seats[combatant.owner_seat]
	return null


func living_heroes() -> Array[PlayerCombatant]:
	var out: Array[PlayerCombatant] = []
	for s in seats:
		if not s.player.is_dead:
			out.append(s.player)
	return out


## True while the active seat is the one this client shows.
func _home() -> bool:
	return seat.index == home_seat


## Signals for another hero's private state (hand, energy...) collapse into this.
func _seat_updated() -> void:
	if not _home():
		EventBus.seat_updated.emit(seat.index)


# =============================================================================
# Queries
# =============================================================================

func is_over() -> bool:
	return phase == Phase.ENDED


func living_enemies() -> Array[EnemyCombatant]:
	var out: Array[EnemyCombatant] = []
	for enemy in enemies:
		if not enemy.is_dead:
			out.append(enemy)
	return out


## The active hero's living summons.
func living_summons() -> Array[SummonCombatant]:
	return _living_summons_of(seat)


func _living_summons_of(s: PlayerSeat) -> Array[SummonCombatant]:
	var out: Array[SummonCombatant] = []
	for summon in s.summons:
		if not summon.is_dead:
			out.append(summon)
	return out


## Enemies see every hero and every summon; heroes see the enemies.
func living_opponents_of(combatant: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = []
	if combatant == null or combatant.side == Combatant.Side.PLAYER:
		out.assign(living_enemies())
	else:
		for s in seats:
			if not s.player.is_dead:
				out.append(s.player)
			out.append_array(_living_summons_of(s))
	return out


## A hero's allies are their own summons (and themselves); other heroes are
## not included, so solo cards keep their meaning in co-op.
func living_allies_of(combatant: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = []
	if combatant == null or combatant.side == Combatant.Side.PLAYER:
		var s := seat_of(combatant) if combatant != null else seat
		if not s.player.is_dead:
			out.append(s.player)
		out.append_array(_living_summons_of(s))
	else:
		out.assign(living_enemies())
	return out


## The summon that takes single-target enemy attacks: a Taunting one if any,
## otherwise the frontmost. Null = the attack hits the player.
func front_summon() -> SummonCombatant:
	var living := living_summons()
	for s in living:
		if s.has_status(&"taunt"):
			return s
	return living[0] if not living.is_empty() else null


## Adds a player-side ally. Returns null when the board is full (3).
func summon_ally(data: EnemyData) -> SummonCombatant:
	if data == null or is_over() or living_summons().size() >= MAX_SUMMONS:
		return null
	var s := SummonCombatant.new(data, data.roll_hp(rng.get_stream(&"combat")))
	s.owner_seat = seat.index
	summons.append(s)
	EventBus.combatant_spawned.emit(s)
	_apply_starting_statuses(s)
	_roll_intent(s)
	_fire_all(EffectTrigger.Timing.SUMMON_CREATED, {"summon": s, "target": s})
	return s


## Destroys every living summon. Returns how many.
func sacrifice_summons() -> int:
	var living := living_summons()
	for s in living:
		_kill(s)
	return living.size()


func get_max_energy() -> int:
	var total := player.class_data.energy_per_turn + int(player.stat_flat(&"energy_per_turn_per_stack"))
	for relic in relics:
		total += relic.max_energy_bonus
	return maxi(total, 0)


func get_draw_per_turn() -> int:
	var total := player.class_data.cards_per_turn + int(player.stat_flat(&"draw_per_turn_per_stack"))
	for relic in relics:
		total += relic.draw_per_turn_bonus
	return maxi(total, 0)


## Empty string if the card can be played on that target, otherwise the reason
## (shown to the player when they try).
func can_play(card: CardInstance, target: Combatant = null) -> String:
	if phase != Phase.PLAYER_TURN or seat.ended_turn or player.is_dead:
		return "Not your turn"
	if not pending_choice.is_empty():
		return "Choose cards first"
	if not hand.has(card):
		return "Card is not in your hand"
	if not card.data.is_playable_type():
		return "This card can't be played"
	var cost := card.get_cost()
	if cost != CardData.COST_X and cost > player.energy:
		return "Not enough energy"
	if card.data.target_mode == CardData.TargetMode.SINGLE_ENEMY:
		if target == null or target.is_dead or not enemies.has(target):
			return "Choose a target"
	return ""


func is_affordable(card: CardInstance) -> bool:
	var cost := card.get_cost()
	return card.data.is_playable_type() and (cost == CardData.COST_X or cost <= player.energy)


## Damage per hit and hit count of an enemy's telegraphed attack, after all
## modifiers, against [param against] (default: the home hero). Vector2i(0, 0)
## if it isn't attacking.
func get_intent_damage(enemy: EnemyCombatant, against: Combatant = null) -> Vector2i:
	var move := enemy.next_move
	if move == null or enemy.skips_turn():
		return Vector2i.ZERO
	var ctx := _move_context(enemy, move)
	if not enemy is SummonCombatant:
		ctx.chosen_target = against if against != null else seats[home_seat].player
	for effect in move.effects:
		if effect is DealDamageEffect and effect.damage_type == DamageInfo.Type.ATTACK:
			return Vector2i(effect.preview_amount(ctx), effect.times)
	return Vector2i.ZERO


# =============================================================================
# Turn flow
# =============================================================================

func start() -> void:
	assert(phase == Phase.NOT_STARTED, "CombatState.start() called twice")
	for s in seats:
		use_seat(s.index)
		rng.shuffle(draw_pile, &"shuffle")
		# Innate cards go on top so they're in the opening hand.
		var innate: Array[CardInstance] = []
		for card in draw_pile:
			if card.has_keyword(CardData.KW_INNATE):
				innate.append(card)
		for card in innate:
			draw_pile.erase(card)
			draw_pile.append(card)

	EventBus.combat_started.emit(encounter)
	for s in seats:
		use_seat(s.index)
		var res := player.get_resource_data()
		if res:
			player.resource_value = res.starting_value
			if _home():
				EventBus.class_resource_changed.emit(res.id, 0, player.resource_value, res.max_value)
	use_seat(home_seat)
	for enemy in enemies:
		_apply_starting_statuses(enemy)
		if ascension >= AscensionRules.ELITE_AFFIX_LEVEL and enemy.data.tier == EnemyData.Tier.ELITE:
			_apply_elite_affix(enemy)
	for s in seats:
		fire(EffectTrigger.Timing.COMBAT_START, s.player)
	for enemy in enemies:
		fire(EffectTrigger.Timing.COMBAT_START, enemy)
	_flush()
	for enemy in living_enemies():
		_roll_intent(enemy)
	_start_player_turn()


## The active hero is done for this turn. In solo (or once every living hero
## is done) the heroes' end-of-turn steps run, then the enemy phase.
func end_player_turn() -> void:
	if phase != Phase.PLAYER_TURN or not pending_choice.is_empty() or seat.ended_turn:
		return
	seat.ended_turn = true
	if _home():
		EventBus.player_input_enabled.emit(false)
	EventBus.seat_ready_changed.emit(seat.index, true)
	_try_finish_player_turns()


## Once every living hero has ended their turn: their end-of-turn steps (in
## seat order), then the enemy phase.
func _try_finish_player_turns() -> void:
	if phase != Phase.PLAYER_TURN or is_over():
		return
	for s in seats:
		if not s.ended_turn and not s.player.is_dead:
			return
	for s in seats:
		if s.player.is_dead:
			continue
		use_seat(s.index)
		_end_seat_turn()
		if is_over():
			use_seat(home_seat)
			return
	use_seat(home_seat)
	for s in seats:
		for card in s.draw_pile + s.discard_pile + s.hand:
			card.cost_override_this_turn = -99
	for s in seats:
		if not s.player.is_dead:
			EventBus.turn_ended.emit(s.player, true)
	_run_enemy_phase()


## One hero's end of turn: turn-end triggers, held-card effects, discard,
## status decay, then their summons act.
func _end_seat_turn() -> void:
	fire(EffectTrigger.Timing.TURN_END, player)
	_flush()
	if is_over():
		return

	var res := player.get_resource_data()
	if res and res.max_triggers_at_turn_end and not res.on_reach_max_effects.is_empty() \
			and player.resource_value >= res.max_value:
		_trigger_resource_max()
		_flush()
		if is_over():
			return

	for card in hand.duplicate():
		if not card.data.end_of_turn_in_hand_effects.is_empty():
			_run_effects(card.data.end_of_turn_in_hand_effects, _card_context(card, null))
	_flush()
	if is_over():
		return

	_discard_hand()
	_end_eclipse()
	_end_turn_decay(player)
	_run_summon_phase()


func _start_player_turn() -> void:
	if is_over():
		return
	round_number += 1
	if round_number > ROUND_LIMIT:
		_end(Result.DEFEAT)
		return
	phase = Phase.PLAYER_TURN
	_once_per_turn_fired.clear()
	EventBus.round_started.emit(round_number)
	for s in seats:
		s.ended_turn = s.player.is_dead
		if s.player.is_dead:
			continue
		use_seat(s.index)
		cards_played_this_turn = 0
		stance_changes_this_turn = 0
		_begin_turn(player)
		if is_over():
			break
		if player.is_dead:
			s.ended_turn = true
			continue
		player.energy = get_max_energy()
		if _home():
			EventBus.energy_changed.emit(player.energy, get_max_energy())
		var res := player.get_resource_data()
		if res and not res.persists_between_turns:
			set_class_resource(res.starting_value)
		draw_cards(get_draw_per_turn())
		fire(EffectTrigger.Timing.TURN_START_POST_DRAW, player)
		_flush()
		if is_over():
			break
		_seat_updated()
	use_seat(home_seat)
	for s in seats:
		EventBus.seat_ready_changed.emit(s.index, s.ended_turn)
	if not is_over() and not seat.ended_turn:
		EventBus.player_input_enabled.emit(true)


func _run_enemy_phase() -> void:
	phase = Phase.ENEMY_TURN
	for enemy in enemies.duplicate():
		if is_over():
			return
		if enemy.is_dead:
			continue
		_begin_turn(enemy)
		if is_over():
			return
		if enemy.is_dead:
			continue
		enemy.turns_taken += 1
		enemy.hp_history.append(enemy.hp)
		if not enemy.skips_turn() and enemy.next_move != null:
			_execute_move(enemy, enemy.next_move)
		_flush()
		if is_over():
			return
		if not enemy.is_dead:
			fire(EffectTrigger.Timing.TURN_END, enemy)
			_flush()
			if is_over():
				return
			_end_turn_decay(enemy)
		EventBus.turn_ended.emit(enemy, false)

	for combatant in _all_living():
		fire(EffectTrigger.Timing.ROUND_END, combatant)
	_flush()
	if is_over():
		return
	for combatant in _all_living():
		_decay(combatant, StatusEffectData.Decay.DECREMENT_ON_ROUND_END)
	for enemy in living_enemies():
		_roll_intent(enemy)
	_start_player_turn()


func _begin_turn(combatant: Combatant) -> void:
	if combatant.block > 0 and not combatant.retains_block():
		combatant.block = 0
		EventBus.block_cleared.emit(combatant)
	EventBus.turn_started.emit(combatant, combatant is PlayerCombatant)
	fire(EffectTrigger.Timing.TURN_START, combatant)
	_flush()
	if not combatant.is_dead:
		_decay(combatant, StatusEffectData.Decay.DECREMENT_ON_TURN_START)
		_decay(combatant, StatusEffectData.Decay.REMOVE_ON_TURN_START)


func _end_turn_decay(combatant: Combatant) -> void:
	_decay(combatant, StatusEffectData.Decay.REMOVE_ON_TURN_END)
	_decay(combatant, StatusEffectData.Decay.DECREMENT_ON_TURN_END)
	_decay(combatant, StatusEffectData.Decay.HALVE_ON_TURN_END)


## Every living combatant: each hero followed by their summons, then enemies.
func _all_living() -> Array[Combatant]:
	var out: Array[Combatant] = []
	for s in seats:
		if not s.player.is_dead:
			out.append(s.player)
		out.append_array(_living_summons_of(s))
	out.append_array(living_enemies())
	return out


## The active hero, their summons and the enemies (who may react to a hero's
## cards). Other heroes don't hear this hero's events.
func _living_for_seat() -> Array[Combatant]:
	var out: Array[Combatant] = []
	if not player.is_dead:
		out.append(player)
	out.append_array(living_summons())
	out.append_array(living_enemies())
	return out


## Summons act after the player's turn, before the enemies. Their Block lasts
## through the enemy turn.
func _run_summon_phase() -> void:
	for s in summons.duplicate():
		if is_over():
			return
		if s.is_dead:
			continue
		if s.block > 0 and not s.retains_block():
			s.block = 0
			EventBus.block_cleared.emit(s)
		fire(EffectTrigger.Timing.TURN_START, s)
		_flush()
		if is_over():
			return
		if s.is_dead:
			continue
		_decay(s, StatusEffectData.Decay.DECREMENT_ON_TURN_START)
		_decay(s, StatusEffectData.Decay.REMOVE_ON_TURN_START)
		s.turns_taken += 1
		if not s.skips_turn() and s.next_move != null:
			_execute_move(s, s.next_move)
		_flush()
		if is_over():
			return
		if not s.is_dead:
			fire(EffectTrigger.Timing.TURN_END, s)
			_flush()
			_end_turn_decay(s)
	for s in living_summons():
		_roll_intent(s)


# =============================================================================
# Cards
# =============================================================================

func play_card(card: CardInstance, target: Combatant = null) -> bool:
	if can_play(card, target) != "":
		return false
	var cost := card.get_cost()
	var x := 0
	if cost == CardData.COST_X:
		x = player.energy
		spend_energy(x)
	else:
		spend_energy(cost)
	hand.erase(card)
	cards_played_this_turn += 1

	var targets: Array[Combatant] = []
	match card.data.target_mode:
		CardData.TargetMode.SINGLE_ENEMY:
			targets.append(target)
		CardData.TargetMode.ALL_ENEMIES:
			targets.assign(living_enemies())
	if _home():
		EventBus.card_played.emit(card, targets)
	else:
		EventBus.ally_card_played.emit(seat.index, card, targets)

	var ctx := _card_context(card, target)
	ctx.x_value = x
	_run_effects(card.data.effects, ctx)

	if card.data.type == CardData.CardType.POWER:
		pass  # Powers leave play; their effect lives on as a status.
	elif card.has_keyword(CardData.KW_EXHAUST):
		_exhaust(card)
	else:
		discard_pile.append(card)
		if _home():
			EventBus.card_discarded.emit(card, false)

	var payload := {"card": card}
	_fire_all(EffectTrigger.Timing.CARD_PLAYED, payload)
	match card.data.type:
		CardData.CardType.ATTACK:
			_fire_all(EffectTrigger.Timing.ATTACK_PLAYED, payload)
		CardData.CardType.SKILL:
			_fire_all(EffectTrigger.Timing.SKILL_PLAYED, payload)
		CardData.CardType.POWER:
			_fire_all(EffectTrigger.Timing.POWER_PLAYED, payload)
	_flush()
	_check_end()
	_seat_updated()
	_after_command()
	return true


## Co-op: a hero who fell during their own turn no longer holds up the party.
func _after_command() -> void:
	if is_coop() and player.is_dead and phase == Phase.PLAYER_TURN and not seat.ended_turn:
		seat.ended_turn = true
		EventBus.seat_ready_changed.emit(seat.index, true)
		var acting := seat.index
		_try_finish_player_turns()
		if not is_over() and seat.index == acting:
			use_seat(acting)


## Uses a potion in combat. The caller removes it from the potion belt.
func can_use_potion(potion: PotionData, target: Combatant = null) -> String:
	if phase != Phase.PLAYER_TURN or seat.ended_turn or player.is_dead:
		return "Not your turn"
	if potion.target_mode == CardData.TargetMode.SINGLE_ENEMY and (target == null or target.is_dead or not enemies.has(target)):
		return "Choose a target"
	return ""


func use_potion(potion: PotionData, target: Combatant = null) -> bool:
	if can_use_potion(potion, target) != "":
		return false
	_run_effects(potion.effects, EffectContext.new(self, player, target))
	_flush()
	_check_end()
	_seat_updated()
	_after_command()
	return true


func draw_cards(count: int) -> void:
	for i in count:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				return
			_reshuffle()
		if hand.size() >= player.class_data.max_hand_size:
			return
		var card: CardInstance = draw_pile.pop_back()
		hand.append(card)
		if _home():
			EventBus.card_drawn.emit(card)
		fire(EffectTrigger.Timing.CARD_DRAWN, player, {"card": card})


## Manual discard from hand (Scribe effects). Triggers Footnotes.
func discard_card(card: CardInstance) -> void:
	if not hand.has(card):
		return
	hand.erase(card)
	discard_pile.append(card)
	if _home():
		EventBus.card_discarded.emit(card, true)
	if not card.data.on_discard_effects.is_empty():
		_run_effects(card.data.on_discard_effects, _card_context(card, null))
	fire(EffectTrigger.Timing.CARD_DISCARDED, player, {"card": card})


func exhaust_card(card: CardInstance) -> void:
	for pile in [hand, draw_pile, discard_pile]:
		if pile.has(card):
			pile.erase(card)
			_exhaust(card)
			return


## Creates a new card mid-combat (status cards from enemies, generated cards).
func add_card_to_pile(card_data: CardData, pile: Pile, upgraded: bool = false) -> CardInstance:
	var card := CardInstance.new(card_data, upgraded)
	match pile:
		Pile.DRAW:
			var index := rng.get_stream(&"shuffle").randi_range(0, draw_pile.size())
			draw_pile.insert(index, card)
		Pile.HAND:
			if hand.size() < player.class_data.max_hand_size:
				hand.append(card)
			else:
				pile = Pile.DISCARD
				discard_pile.append(card)
		Pile.DISCARD:
			discard_pile.append(card)
		Pile.EXHAUST:
			exhaust_pile.append(card)
	if _home():
		EventBus.card_created.emit(card, StringName(Pile.keys()[pile].to_lower()))
	return card


func _reshuffle() -> void:
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	rng.shuffle(draw_pile, &"shuffle")
	if _home():
		EventBus.deck_shuffled.emit(draw_pile.size())
	fire(EffectTrigger.Timing.DECK_SHUFFLED, player)


func _exhaust(card: CardInstance) -> void:
	exhaust_pile.append(card)
	if _home():
		EventBus.card_exhausted.emit(card)
	fire(EffectTrigger.Timing.CARD_EXHAUSTED, player, {"card": card})


func _discard_hand() -> void:
	for card in hand.duplicate():
		if card.has_keyword(CardData.KW_RETAIN):
			if _home():
				EventBus.card_retained.emit(card)
			continue
		hand.erase(card)
		if card.has_keyword(CardData.KW_ETHEREAL):
			_exhaust(card)
		else:
			discard_pile.append(card)
			if _home():
				EventBus.card_discarded.emit(card, false)


func _card_context(card: CardInstance, target: Combatant) -> EffectContext:
	var ctx := EffectContext.new(self, player, target)
	ctx.card = card
	ctx.upgraded = card.upgraded
	return ctx


# =============================================================================
# Energy & class resource
# =============================================================================

func spend_energy(amount: int) -> void:
	player.energy = maxi(player.energy - amount, 0)
	if _home():
		EventBus.energy_changed.emit(player.energy, get_max_energy())


func gain_energy(amount: int) -> void:
	player.energy = maxi(player.energy + amount, 0)
	if _home():
		EventBus.energy_changed.emit(player.energy, get_max_energy())


## Returns the actual change after clamping.
func change_class_resource(delta: int) -> int:
	var res := player.get_resource_data()
	if res == null or delta == 0:
		return 0
	var old := player.resource_value
	player.resource_value = clampi(old + delta, 0, res.max_value)
	var actual := player.resource_value - old
	if actual == 0:
		return 0
	if _home():
		EventBus.class_resource_changed.emit(res.id, old, player.resource_value, res.max_value)
	if actual > 0:
		_fire_all(EffectTrigger.Timing.CLASS_RESOURCE_GAINED, {"amount": actual})
		if player.resource_value >= res.max_value and not res.max_triggers_at_turn_end \
				and not res.on_reach_max_effects.is_empty():
			_trigger_resource_max()
	else:
		_fire_all(EffectTrigger.Timing.CLASS_RESOURCE_SPENT, {"amount": -actual})
	return actual


func set_class_resource(value: int) -> void:
	change_class_resource(value - player.resource_value)


func _trigger_resource_max() -> void:
	var res := player.get_resource_data()
	if _home():
		EventBus.class_resource_maxed.emit(res.id)
	_run_effects(res.on_reach_max_effects, EffectContext.new(self, player, null))


# =============================================================================
# Stances (Moonblade phases)
# =============================================================================

## Enters [param target] (null = Shift to the other phase). Each real change
## grants 1 class resource (Lunar Charge); changing at max enters the class's
## eclipse stance instead. While in Eclipse, phase changes don't leave it but
## still count as changes for triggers and Moonfall.
func change_stance(target: StatusEffectData = null) -> void:
	var cls := player.class_data
	if cls.stances.size() < 2 or is_over():
		return
	var old := player.stance
	var eclipse := cls.eclipse_stance
	var in_eclipse := eclipse != null and old == eclipse
	if not in_eclipse:
		if target == null:
			target = cls.stances[1] if old == cls.stances[0] else cls.stances[0]
		if target == old:
			return  # Already in that phase: not a change.
	stance_changes_this_turn += 1
	if not in_eclipse:
		var res := player.get_resource_data()
		var full := res != null and player.resource_value >= res.max_value
		if eclipse != null and (target == eclipse or full):
			target = eclipse
		_set_stance(target)
		if target == eclipse:
			_run_effects(cls.eclipse_effects, EffectContext.new(self, player, null))
		else:
			change_class_resource(1)
	_apply_stance_cost_reductions()
	_fire_all(EffectTrigger.Timing.STANCE_CHANGED, {"stance": player.stance})


## True if [param combatant] has the status, or (player only) the status is a
## phase and the player is in Eclipse, which counts as both phases.
func has_status_or_stance(combatant: Combatant, status_id: StringName) -> bool:
	if combatant == null:
		return false
	if combatant.has_status(status_id):
		return true
	var hero := combatant as PlayerCombatant
	if hero == null or hero.stance == null or hero.stance != hero.class_data.eclipse_stance:
		return false
	for stance in hero.class_data.stances:
		if stance.id == status_id:
			return true
	return false


func _set_stance(new_stance: StatusEffectData) -> void:
	var old := player.stance
	player.stance = null
	if old != null:
		remove_status(player, old.id)
	if new_stance != null:
		apply_status(player, new_stance, 1, player)
		player.stance = new_stance
	if _home():
		EventBus.stance_changed.emit(old.id if old else &"", new_stance.id if new_stance else &"")


## Eclipse lasts until the end of the turn, then Lunar Charge resets.
func _end_eclipse() -> void:
	var eclipse := player.class_data.eclipse_stance
	if eclipse == null or player.stance != eclipse:
		return
	_set_stance(null)
	set_class_resource(0)
	_flush()


func _apply_stance_cost_reductions() -> void:
	for card in hand + draw_pile + discard_pile:
		var per := card.data.cost_reduction_per_stance_change
		if per > 0:
			card.cost_override_this_turn = maxi(0, card.data.get_cost(card.upgraded) - per * stance_changes_this_turn)


# =============================================================================
# Damage, block, healing
# =============================================================================

func deal_damage(source: Combatant, target: Combatant, base: int, type: DamageInfo.Type) -> DamageInfo:
	if target == null or target.is_dead or is_over():
		return null
	var info := DamageInfo.new()
	info.source = source
	info.target = target
	info.type = type
	info.base = base
	info.amount = DamageCalc.attack_damage(base, source, target) if type == DamageInfo.Type.ATTACK else maxi(base, 0)
	info.block_before = target.block
	if not DamageInfo.ignores_block(type):
		info.blocked = mini(target.block, info.amount)
		target.block -= info.blocked
	info.hp_lost = mini(info.amount - info.blocked, target.hp)
	target.hp -= info.hp_lost
	info.block_after = target.block
	info.hp_after = target.hp
	info.killed = target.hp <= 0
	var revive := _revive_status(target) if info.killed else null
	if revive:
		info.killed = false
	EventBus.damage_dealt.emit(info)
	if revive:
		_revive(target, revive)

	if info.block_before > 0 and target.block == 0:
		EventBus.block_broken.emit(target)
		fire(EffectTrigger.Timing.BLOCK_BROKEN, target, {"info": info})
	if type == DamageInfo.Type.ATTACK:
		fire(EffectTrigger.Timing.ATTACKED, target, {"attacker": source, "info": info})
		if source != null:
			fire(EffectTrigger.Timing.DEALT_ATTACK_DAMAGE, source, {"info": info})
		if source is SummonCombatant and info.amount > 0:
			fire(EffectTrigger.Timing.SUMMON_DEALT_DAMAGE, seat_of(source).player, {"target": target, "info": info})
	if info.hp_lost > 0 and type == DamageInfo.Type.ATTACK and source != null and not source.is_dead:
		var steal := source.stat_flat(&"attack_lifesteal")
		if steal > 0.0:
			heal(source, maxi(1, floori(info.hp_lost * steal)))
	if info.hp_lost > 0:
		fire(EffectTrigger.Timing.HP_LOST, target, {"info": info})
		for status_id in target.statuses.keys():
			var data: StatusEffectData = target.status_data[status_id]
			if data.lose_stack_on_hp_lost:
				_set_stacks(target, data, target.get_stacks(status_id) - 1)

	if info.killed:
		_kill(target)
	elif target is EnemyCombatant and not target is SummonCombatant:
		_check_phase_change(target)
	return info


func gain_block(target: Combatant, base: int) -> int:
	if target == null or target.is_dead:
		return 0
	var amount := DamageCalc.block_amount(base, target)
	if amount <= 0:
		return 0
	target.block = mini(target.block + amount, MAX_BLOCK)
	EventBus.block_gained.emit(target, amount, target.block)
	return amount


func heal(target: Combatant, amount: int) -> void:
	if target == null or target.is_dead or amount <= 0:
		return
	var healed := mini(amount, target.max_hp - target.hp)
	if healed <= 0:
		return
	target.hp += healed
	EventBus.healed.emit(target, healed, target.hp)


## A cheat-death status on [param target] that can fire now, or null.
func _revive_status(target: Combatant) -> StatusEffectData:
	if not target is EnemyCombatant or target is SummonCombatant:
		return null
	var others := living_enemies().filter(func(e): return e != target and e.hp > 0)
	if others.is_empty():
		return null
	for status_id in target.statuses:
		var data: StatusEffectData = target.status_data[status_id]
		if data.revive_hp_percent > 0.0:
			return data
	return null


func _revive(target: Combatant, status: StatusEffectData) -> void:
	remove_status(target, status.id)
	var amount := maxi(1, ceili(target.max_hp * status.revive_hp_percent))
	target.hp = 0
	heal(target, amount)
	var stun := ContentDB.get_status(&"stun")
	if stun:
		apply_status(target, stun, 1)
	if target is EnemyCombatant:
		_emit_intent(target)


## Thieves (Coin Mimic). Returns what was actually taken.
func steal_gold(thief: EnemyCombatant, amount: int) -> int:
	var taken := clampi(amount, 0, player_gold)
	if taken <= 0:
		return 0
	player_gold -= taken
	thief.stolen_gold += taken
	seat.stolen[thief.id] = int(seat.stolen.get(thief.id, 0)) + taken
	if _home():
		EventBus.gold_stolen.emit(thief, taken)
	return taken


## The enemy flees: gone from the fight, but its stolen gold goes with it.
func escape(enemy: EnemyCombatant) -> void:
	if enemy.is_dead or is_over():
		return
	enemy.is_dead = true
	enemy.escaped = true
	enemy.block = 0
	EventBus.combatant_escaped.emit(enemy)
	_check_end()


func _kill(target: Combatant) -> void:
	target.hp = 0
	target.block = 0
	target.is_dead = true
	EventBus.combatant_died.emit(target)
	if target is EnemyCombatant and target.stolen_gold > 0:
		for s in seats:
			var back: int = s.stolen.get(target.id, 0)
			if back > 0:
				s.player_gold += back
				s.stolen.erase(target.id)
				if s.index == home_seat:
					EventBus.gold_stolen.emit(target, -back)
		target.stolen_gold = 0
	fire(EffectTrigger.Timing.OWNER_DIED, target)
	if target is SummonCombatant:
		fire(EffectTrigger.Timing.SUMMON_DIED, seat_of(target).player, {"summon": target, "target": target})
	elif target is EnemyCombatant:
		for s in seats:
			fire(EffectTrigger.Timing.ENEMY_DIED, s.player, {"enemy": target})
	elif target is PlayerCombatant and is_coop():
		# A fallen hero's summons fall with them.
		for summon in _living_summons_of(seat_of(target)):
			_kill(summon)
	_check_end()


func _check_end() -> void:
	if is_over() or _ending:
		return
	if living_heroes().is_empty():
		_end(Result.DEFEAT)
	elif living_enemies().is_empty():
		_end(Result.VICTORY)


func _end(p_result: Result) -> void:
	if is_over() or _ending:
		return
	_ending = true
	result = p_result
	queue.clear()
	if result == Result.VICTORY:
		# Post-combat relics (heal after fight, etc.) resolve right away.
		for s in seats:
			fire(EffectTrigger.Timing.COMBAT_END, s.player, {}, true)
	phase = Phase.ENDED
	EventBus.player_input_enabled.emit(false)
	EventBus.combat_ended.emit(result == Result.VICTORY)


# =============================================================================
# Statuses
# =============================================================================

func apply_status(target: Combatant, data: StatusEffectData, stacks: int, source: Combatant = null) -> void:
	if target == null or target.is_dead or data == null or stacks == 0 or is_over():
		return
	var old := target.get_stacks(data.id)
	if data.stack_mode == StatusEffectData.StackMode.FLAG and old != 0:
		return
	var new_value := 1 if data.stack_mode == StatusEffectData.StackMode.FLAG else old + stacks
	_set_stacks(target, data, new_value)
	if target.get_stacks(data.id) == old:
		return
	if stacks > 0 and phase == Phase.ENEMY_TURN \
			and data.decay == StatusEffectData.Decay.DECREMENT_ON_ROUND_END:
		target.skip_next_round_decay[data.id] = true
	var payload := {"status": data, "source": source, "stacks": stacks}
	fire(EffectTrigger.Timing.STATUS_APPLIED_TO_OWNER, target, payload)
	if source != null:
		fire(EffectTrigger.Timing.OWNER_APPLIED_STATUS, source, payload)


func remove_status(target: Combatant, status_id: StringName) -> void:
	if not target.has_status(status_id):
		return
	var data: StatusEffectData = target.status_data[status_id]
	target.statuses.erase(status_id)
	target.status_data.erase(status_id)
	target.skip_next_round_decay.erase(status_id)
	EventBus.status_removed.emit(target, data)
	var hero := target as PlayerCombatant
	if hero != null and hero.stance != null and hero.stance.id == status_id:
		hero.stance = null
		if hero.seat_index == home_seat:
			EventBus.stance_changed.emit(status_id, &"")
	_refresh_intents()


## Sets stacks directly (clamped), removing the status at 0. No triggers.
func _set_stacks(target: Combatant, data: StatusEffectData, value: int) -> void:
	var low := -data.max_stacks if data.allow_negative else 0
	value = clampi(value, low, data.max_stacks)
	var old := target.get_stacks(data.id)
	if value == old:
		return
	if value == 0:
		remove_status(target, data.id)
		return
	target.statuses[data.id] = value
	target.status_data[data.id] = data
	EventBus.status_applied.emit(target, data, value - old, value)
	if not data.max_stack_effects.is_empty() and value > old:
		var cap := data.a15_max_stacks if ascension >= 15 and data.a15_max_stacks > 0 else data.max_stacks
		if value >= cap:
			queue.push(_burst_status.bind(target, data))
	if data.skips_turn and target is EnemyCombatant:
		_emit_intent(target)
	_refresh_intents()


## A meter status reached its cap: unleash its effects and reset it.
func _burst_status(target: Combatant, data: StatusEffectData) -> void:
	if target.is_dead or is_over() or not target.has_status(data.id):
		return
	EventBus.status_triggered.emit(target, data)
	if target is EnemyCombatant and not target is SummonCombatant:
		_run_enemy_effects(target, data.max_stack_effects, EffectContext.new(self, target, null))
	else:
		_run_effects(data.max_stack_effects, EffectContext.new(self, target, player))
	if not target.is_dead:
		_set_stacks(target, data, 0)


func _decay(combatant: Combatant, kind: StatusEffectData.Decay) -> void:
	for status_id in combatant.statuses.keys():
		if not combatant.has_status(status_id):
			continue
		var data: StatusEffectData = combatant.status_data[status_id]
		if data.decay != kind:
			continue
		if kind == StatusEffectData.Decay.DECREMENT_ON_ROUND_END and combatant.skip_next_round_decay.has(status_id):
			combatant.skip_next_round_decay.erase(status_id)
			continue
		var stacks: int = combatant.statuses[status_id]
		match kind:
			StatusEffectData.Decay.REMOVE_ON_TURN_END, StatusEffectData.Decay.REMOVE_ON_TURN_START:
				remove_status(combatant, status_id)
			StatusEffectData.Decay.HALVE_ON_TURN_END:
				_set_stacks(combatant, data, floori(stacks / 2.0))
			_:
				_set_stacks(combatant, data, stacks - 1)


# =============================================================================
# Triggers
# =============================================================================

## Collects every trigger on [param owner] (statuses, relics if player, enemy
## phase passives) listening for [param timing] and queues their reactions.
func fire(timing: EffectTrigger.Timing, owner: Combatant, payload: Dictionary = {}, immediate: bool = false) -> void:
	if owner == null:
		return
	if owner.is_dead and timing != EffectTrigger.Timing.OWNER_DIED:
		return
	for status_id in owner.statuses.keys():
		var data: StatusEffectData = owner.status_data[status_id]
		for trigger in data.triggers:
			if trigger.timing == timing:
				_queue_trigger(trigger, owner, status_id, null, payload, immediate)
	if owner is PlayerCombatant:
		for relic in seats[owner.seat_index].relics:
			for trigger in relic.triggers:
				if trigger.timing == timing:
					_queue_trigger(trigger, owner, &"", relic, payload, immediate)
		for trigger in owner.class_data.class_triggers:
			if trigger.timing == timing:
				_queue_trigger(trigger, owner, &"", null, payload, immediate)
	elif owner is EnemyCombatant:
		var enemy_phase: EnemyPhaseData = owner.current_phase()
		if enemy_phase:
			for trigger in enemy_phase.passive_triggers:
				if trigger.timing == timing:
					_queue_trigger(trigger, owner, &"", null, payload, immediate)


## Card events fire on every combatant: the player's powers react to their own
## cards, and enemy passives can react to them too ("gains Strength whenever
## you play a Skill").
func _fire_all(timing: EffectTrigger.Timing, payload: Dictionary) -> void:
	for combatant in _living_for_seat():
		fire(timing, combatant, payload)


func _queue_trigger(trigger: EffectTrigger, owner: Combatant, status_id: StringName,
		relic: RelicData, payload: Dictionary, immediate: bool) -> void:
	if not _trigger_condition_met(trigger, owner, payload):
		return
	if trigger.once_per_turn:
		var once_key := "%d:%d" % [owner.id, trigger.get_instance_id()]
		if _once_per_turn_fired.has(once_key):
			return
		_once_per_turn_fired[once_key] = true
	if trigger.every_nth > 1:
		var key := "%d:%d" % [owner.id, trigger.get_instance_id()]
		var count: int = _trigger_counts.get(key, 0) + 1
		_trigger_counts[key] = count % trigger.every_nth
		if relic and owner is PlayerCombatant and owner.seat_index == home_seat:
			EventBus.relic_counter_changed.emit(relic, count % trigger.every_nth)
		if count < trigger.every_nth:
			return
	var action := _run_trigger.bind(trigger, owner, status_id, relic, payload)
	if immediate:
		action.call()
	else:
		queue.push(action)


func _trigger_condition_met(trigger: EffectTrigger, owner: Combatant, payload: Dictionary) -> bool:
	if trigger.required_card_tag != &"":
		var card: CardInstance = payload.get("card")
		if card == null or not card.data.tags.has(trigger.required_card_tag):
			return false
	if trigger.required_card_type >= 0:
		var typed: CardInstance = payload.get("card")
		if typed == null or (typed.data.type != trigger.required_card_type and typed.data.type != trigger.required_card_type_alt):
			return false
	var info: DamageInfo = payload.get("info")
	match trigger.condition:
		EffectTrigger.Condition.HIT_WHILE_BLOCKING:
			return info != null and info.block_before > 0
		EffectTrigger.Condition.UNBLOCKED_HIT:
			return info != null and info.hp_lost > 0
		EffectTrigger.Condition.REQUIRES_STATUS:
			return has_status_or_stance(owner, trigger.required_status_id)
		EffectTrigger.Condition.FIRST_TURN:
			return round_number <= 1
	return true


func _run_trigger(trigger: EffectTrigger, owner: Combatant, status_id: StringName,
		relic: RelicData, payload: Dictionary) -> void:
	if owner.is_dead and trigger.timing != EffectTrigger.Timing.OWNER_DIED:
		return
	var stacks := 0
	if status_id != &"":
		stacks = owner.get_stacks(status_id)
		if stacks == 0:
			return  # Removed while the reaction was queued.
	var ctx := EffectContext.new(self, owner, null)
	ctx.payload = payload
	if trigger.amount_from_stacks:
		ctx.amount_override = absi(stacks)
	# A hero's (or summon's) reactions resolve on that hero's seat.
	var previous := seat
	var owner_seat := seat_of(owner)
	if owner_seat != null:
		seat = owner_seat
	if relic and _home():
		EventBus.relic_triggered.emit(relic)
	if status_id != &"":
		EventBus.status_triggered.emit(owner, owner.status_data[status_id])
	_run_effects(trigger.effects, ctx)
	seat = previous
	if status_id != &"" and owner.has_status(status_id):
		var data: StatusEffectData = owner.status_data[status_id]
		match data.decay:
			StatusEffectData.Decay.DECREMENT_ON_TRIGGER:
				_set_stacks(owner, data, owner.get_stacks(status_id) - 1)
			StatusEffectData.Decay.REMOVE_ON_TRIGGER:
				remove_status(owner, status_id)


func _run_effects(effects: Array[GameEffect], ctx: EffectContext) -> void:
	for i in effects.size():
		if is_over():
			return
		var effect := effects[i]
		effect.execute(ctx)
		if not pending_choice.is_empty() and pending_choice.effect == effect and not pending_choice.has("rest"):
			# Waiting for the player: the rest of this list runs in resolve_choice.
			var rest: Array[GameEffect] = []
			rest.assign(effects.slice(i + 1))
			pending_choice.rest = rest
			return


# =============================================================================
# Card choices (discard / Erase / take from draw pile)
# =============================================================================

## Called by ChooseCardsEffect. Resolves immediately when the outcome is
## forced or nobody is choosing interactively; otherwise stores a pending
## choice and emits EventBus.card_choice_requested.
func request_choice(effect: ChooseCardsEffect, ctx: EffectContext) -> void:
	var options: Array[CardInstance] = []
	options.assign(draw_pile if effect.mode == ChooseCardsEffect.Mode.DRAW_TO_HAND else hand)
	var max_count := mini(ctx.amount_for(effect), options.size())
	var min_count := 0 if effect.up_to else max_count
	ctx.x_value = 0
	if max_count <= 0:
		return
	if not effect.up_to and options.size() <= max_count:
		_apply_choice(effect.mode, options.duplicate())
		ctx.x_value = options.size()
		return
	if not interactive or phase != Phase.PLAYER_TURN:
		var chooser := auto_choose if auto_choose.is_valid() else default_choice
		var chosen: Array = chooser.call(options, min_count, max_count, effect.mode)
		chosen = chosen.filter(func(c): return options.has(c)).slice(0, max_count)
		_apply_choice(effect.mode, chosen)
		ctx.x_value = chosen.size()
		return
	pending_choice = {"effect": effect, "ctx": ctx, "options": options, "min": min_count, "max": max_count}
	if _home():
		EventBus.player_input_enabled.emit(false)
		EventBus.card_choice_requested.emit(effect.get_prompt(max_count), options, min_count, max_count)
	else:
		_seat_updated()


## The player's answer to the pending choice. Returns false if it's invalid.
func resolve_choice(chosen: Array) -> bool:
	if pending_choice.is_empty():
		return false
	var c := pending_choice
	if chosen.size() < c.min or chosen.size() > c.max:
		return false
	for card in chosen:
		if not c.options.has(card):
			return false
	pending_choice = {}
	var effect: ChooseCardsEffect = c.effect
	_apply_choice(effect.mode, chosen)
	if _home():
		EventBus.card_choice_resolved.emit()
	var ctx: EffectContext = c.ctx
	ctx.x_value = chosen.size()
	_run_effects(c.get("rest", [] as Array[GameEffect]), ctx)
	_flush()
	_check_end()
	if not is_over() and pending_choice.is_empty() and phase == Phase.PLAYER_TURN and _home():
		EventBus.player_input_enabled.emit(true)
	_seat_updated()
	_after_command()
	return true


func _apply_choice(mode: ChooseCardsEffect.Mode, chosen: Array) -> void:
	for card: CardInstance in chosen:
		match mode:
			ChooseCardsEffect.Mode.DISCARD:
				discard_card(card)
			ChooseCardsEffect.Mode.EXHAUST:
				exhaust_card(card)
			ChooseCardsEffect.Mode.DRAW_TO_HAND:
				if not draw_pile.has(card):
					continue
				draw_pile.erase(card)
				if hand.size() < player.class_data.max_hand_size:
					hand.append(card)
					if _home():
						EventBus.card_drawn.emit(card)
					fire(EffectTrigger.Timing.CARD_DRAWN, player, {"card": card})
				else:
					discard_pile.append(card)
					if _home():
						EventBus.card_discarded.emit(card, false)


## Simple choice policy for the AI, simulations and tests: get rid of Curses
## and Statuses first, then the cheapest cards; take the priciest card from
## the draw pile.
static func default_choice(options: Array, min_count: int, max_count: int, mode: ChooseCardsEffect.Mode) -> Array:
	var ranked := options.duplicate()
	if mode == ChooseCardsEffect.Mode.DRAW_TO_HAND:
		ranked.sort_custom(func(a, b): return _card_worth(a) > _card_worth(b))
		return ranked.slice(0, max_count)
	var discarding := mode == ChooseCardsEffect.Mode.DISCARD
	# When discarding, Footnote cards are the ones you want to throw away.
	ranked.sort_custom(func(a, b):
		return _card_worth(a) - (6.0 if discarding and not a.data.on_discard_effects.is_empty() else 0.0) \
				< _card_worth(b) - (6.0 if discarding and not b.data.on_discard_effects.is_empty() else 0.0))
	var out: Array = []
	for card in ranked:
		var junk: bool = card.data.type == CardData.CardType.STATUS or card.data.type == CardData.CardType.CURSE
		var has_footnote: bool = not card.data.on_discard_effects.is_empty()
		if out.size() < min_count or (out.size() < max_count and (junk or (has_footnote and mode == ChooseCardsEffect.Mode.DISCARD))):
			out.append(card)
	return out


static func _card_worth(card: CardInstance) -> float:
	if card.data.type == CardData.CardType.STATUS or card.data.type == CardData.CardType.CURSE:
		return -10.0
	var attack_bonus := 1.5 if card.data.type == CardData.CardType.ATTACK else 0.0
	return float(card.data.rarity) * 2.0 + maxf(card.get_cost(), 0) + (1.0 if card.upgraded else 0.0) + attack_bonus


func _flush() -> void:
	queue.flush(is_over)
	_check_end()


# =============================================================================
# Enemies
# =============================================================================

func _apply_starting_statuses(enemy: EnemyCombatant) -> void:
	for entry in enemy.data.starting_statuses:
		apply_status(enemy, entry.status, entry.stacks, enemy)
	if ascension >= 15:
		for entry in enemy.data.a15_starting_statuses:
			apply_status(enemy, entry.status, entry.stacks, enemy)


## Ascension 8: each elite rolls one affix (see AscensionRules.ELITE_AFFIXES).
func _apply_elite_affix(enemy: EnemyCombatant) -> void:
	var id: StringName = rng.pick(AscensionRules.ELITE_AFFIXES, &"combat")
	var status := ContentDB.get_status(id)
	if status == null:
		return
	apply_status(enemy, status, 1, enemy)
	if id == &"affix_armored":
		gain_block(enemy, 15)


func _roll_intent(enemy: EnemyCombatant) -> void:
	var enemy_phase := enemy.current_phase()
	if enemy_phase and enemy_phase.selection == EnemyPhaseData.Selection.SCRIPTED and enemy_phase.ai_script:
		var ai: EnemyAI = enemy_phase.ai_script.new()
		enemy.next_move = ai.choose_move(enemy, self)
	else:
		enemy.next_move = EnemyAI.choose_by_rules(enemy, rng.get_stream(&"combat"), living_enemies().size() - 1)
	_emit_intent(enemy)


func _emit_intent(enemy: EnemyCombatant) -> void:
	var dmg := get_intent_damage(enemy)
	EventBus.intent_changed.emit(enemy, null if enemy.skips_turn() else enemy.next_move, dmg.x, dmg.y)


## Intent numbers depend on Strength/Weak/Vulnerable, so re-announce them after
## any status change.
func _refresh_intents() -> void:
	if phase == Phase.NOT_STARTED:
		return
	for enemy in living_enemies():
		_emit_intent(enemy)
	for s in living_summons():
		_emit_intent(s)


func _move_context(enemy: EnemyCombatant, move: EnemyMoveData) -> EffectContext:
	var target: Combatant = player
	if not enemy is SummonCombatant and player.is_dead:
		var heroes := living_heroes()
		target = heroes[0] if not heroes.is_empty() else player
	if enemy is SummonCombatant:
		var foes := living_enemies()
		target = foes[0] if not foes.is_empty() else null
	var ctx := EffectContext.new(self, enemy, target)
	ctx.bonus = AscensionRules.move_bonus(move, ascension)
	ctx.damage_multiplier = AscensionRules.enemy_damage_multiplier(enemy.data.tier, ascension)
	return ctx


func _execute_move(enemy: EnemyCombatant, move: EnemyMoveData) -> void:
	enemy.move_history.append(move.id)
	for move_id in enemy.cooldowns.keys():
		enemy.cooldowns[move_id] = maxi(int(enemy.cooldowns[move_id]) - 1, 0)
	if move.cooldown > 0:
		enemy.cooldowns[move.id] = move.cooldown
	var ctx := _move_context(enemy, move)
	if get_intent_damage(enemy, ctx.chosen_target).x > 0 or _is_attack_intent(move.intent):
		var attack_targets: Array = []
		if enemy is SummonCombatant:
			if ctx.chosen_target:
				attack_targets.append(ctx.chosen_target)
		else:
			attack_targets.assign(living_heroes())
		EventBus.attack_started.emit(enemy, attack_targets)
	if enemy is SummonCombatant:
		for effect in move.effects:
			if is_over() or enemy.is_dead:
				return
			effect.execute(ctx)
	else:
		_run_enemy_effects(enemy, move.effects, ctx)


## Runs an enemy's effects. Effects aimed at "the player" (see
## GameEffect.per_player) run once for each living hero, with that hero's seat
## active; the rest (self-buffs, summoning minions) run once.
func _run_enemy_effects(enemy: EnemyCombatant, effects: Array[GameEffect], ctx: EffectContext) -> void:
	var previous := seat
	for effect in effects:
		if is_over() or enemy.is_dead:
			break
		if effect.per_player():
			for s in seats:
				if is_over() or enemy.is_dead:
					break
				if s.player.is_dead:
					continue
				seat = s
				ctx.chosen_target = s.player
				effect.execute(ctx)
		else:
			if player.is_dead:
				var heroes := living_heroes()
				if not heroes.is_empty():
					seat = seats[heroes[0].seat_index]
			ctx.chosen_target = player
			effect.execute(ctx)
	seat = previous


static func _is_attack_intent(intent: EnemyMoveData.Intent) -> bool:
	return intent in [
		EnemyMoveData.Intent.ATTACK, EnemyMoveData.Intent.ATTACK_BUFF,
		EnemyMoveData.Intent.ATTACK_DEBUFF, EnemyMoveData.Intent.ATTACK_DEFEND,
	]


func _check_phase_change(enemy: EnemyCombatant) -> void:
	var changed := false
	var next := enemy.phase_index + 1
	while next < enemy.data.phases.size() and enemy.hp_ratio() <= enemy.data.phases[next].hp_threshold:
		enemy.phase_index = next
		enemy.opening_index = 0
		enemy.sequence_index = 0
		changed = true
		next += 1
	if not changed:
		return
	var new_phase := enemy.current_phase()
	EventBus.boss_phase_changed.emit(enemy, enemy.phase_index, new_phase)
	_run_enemy_effects(enemy, new_phase.on_enter_effects, EffectContext.new(self, enemy, player))
	_roll_intent(enemy)
