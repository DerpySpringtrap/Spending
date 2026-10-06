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

enum Phase { NOT_STARTED, PLAYER_TURN, ENEMY_TURN, ENDED }
enum Result { NONE, VICTORY, DEFEAT }
enum Pile { DRAW, HAND, DISCARD, EXHAUST }

## Safety net for simulations with degenerate decks.
const ROUND_LIMIT := 100
const MAX_BLOCK := 999

var player: PlayerCombatant
var enemies: Array[EnemyCombatant] = []
var draw_pile: Array[CardInstance] = []  ## Top of the pile is the END of the array.
var hand: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []
var exhaust_pile: Array[CardInstance] = []
var relics: Array[RelicData] = []
var encounter: EncounterData
var ascension: int = 0
var rng: RngStreams

var round_number: int = 0
var phase: Phase = Phase.NOT_STARTED
var result: Result = Result.NONE
var cards_played_this_turn: int = 0

var queue := ActionQueue.new()
var _trigger_counts: Dictionary = {}  # "<owner id>:<trigger instance id>" -> int
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
	var combat := CombatState.new()
	combat.player = PlayerCombatant.new(class_data, hp, max_hp)
	combat.relics = p_relics.duplicate()
	combat.encounter = p_encounter
	combat.ascension = p_ascension
	combat.rng = p_rng
	for card in deck:
		combat.draw_pile.append(card.clone_for_combat())
	for enemy_data in p_encounter.enemies:
		combat.add_enemy(enemy_data)
	return combat


## Adds an enemy (encounter setup or mid-fight summons). Returns it.
func add_enemy(enemy_data: EnemyData) -> EnemyCombatant:
	var hp := enemy_data.roll_hp(rng.get_stream(&"combat"))
	hp = ceili(hp * AscensionRules.enemy_hp_multiplier(enemy_data.tier, ascension))
	var enemy := EnemyCombatant.new(enemy_data, hp)
	enemies.append(enemy)
	if phase != Phase.NOT_STARTED:
		EventBus.combatant_spawned.emit(enemy)
		_apply_starting_statuses(enemy)
		_roll_intent(enemy)
	return enemy


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


func living_opponents_of(combatant: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = []
	if combatant == null or combatant.side == Combatant.Side.PLAYER:
		out.assign(living_enemies())
	elif not player.is_dead:
		out.append(player)
	return out


func living_allies_of(combatant: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = []
	if combatant == null or combatant.side == Combatant.Side.PLAYER:
		if not player.is_dead:
			out.append(player)
	else:
		out.assign(living_enemies())
	return out


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
	if phase != Phase.PLAYER_TURN:
		return "Not your turn"
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
## modifiers. Vector2i(0, 0) if it isn't attacking.
func get_intent_damage(enemy: EnemyCombatant) -> Vector2i:
	var move := enemy.next_move
	if move == null or enemy.skips_turn():
		return Vector2i.ZERO
	var ctx := _move_context(enemy, move)
	for effect in move.effects:
		if effect is DealDamageEffect and effect.damage_type == DamageInfo.Type.ATTACK:
			return Vector2i(effect.preview_amount(ctx), effect.times)
	return Vector2i.ZERO


# =============================================================================
# Turn flow
# =============================================================================

func start() -> void:
	assert(phase == Phase.NOT_STARTED, "CombatState.start() called twice")
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
	var res := player.get_resource_data()
	if res:
		player.resource_value = res.starting_value
		EventBus.class_resource_changed.emit(res.id, 0, player.resource_value, res.max_value)
	for enemy in enemies:
		_apply_starting_statuses(enemy)
	fire(EffectTrigger.Timing.COMBAT_START, player)
	for enemy in enemies:
		fire(EffectTrigger.Timing.COMBAT_START, enemy)
	_flush()
	for enemy in living_enemies():
		_roll_intent(enemy)
	_start_player_turn()


func end_player_turn() -> void:
	if phase != Phase.PLAYER_TURN:
		return
	EventBus.player_input_enabled.emit(false)
	fire(EffectTrigger.Timing.TURN_END, player)
	_flush()
	if is_over():
		return

	var res := player.get_resource_data()
	if res and res.max_triggers_at_turn_end and player.resource_value >= res.max_value:
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
	_end_turn_decay(player)
	for card in draw_pile + discard_pile + hand:
		card.cost_override_this_turn = -99
	EventBus.turn_ended.emit(player, true)
	_run_enemy_phase()


func _start_player_turn() -> void:
	if is_over():
		return
	round_number += 1
	if round_number > ROUND_LIMIT:
		_end(Result.DEFEAT)
		return
	phase = Phase.PLAYER_TURN
	cards_played_this_turn = 0
	EventBus.round_started.emit(round_number)
	_begin_turn(player)
	if is_over():
		return
	player.energy = get_max_energy()
	EventBus.energy_changed.emit(player.energy, get_max_energy())
	var res := player.get_resource_data()
	if res and not res.persists_between_turns:
		set_class_resource(res.starting_value)
	draw_cards(get_draw_per_turn())
	fire(EffectTrigger.Timing.TURN_START_POST_DRAW, player)
	_flush()
	if not is_over():
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
	EventBus.turn_started.emit(combatant, combatant == player)
	fire(EffectTrigger.Timing.TURN_START, combatant)
	_flush()
	if not combatant.is_dead:
		_decay(combatant, StatusEffectData.Decay.DECREMENT_ON_TURN_START)


func _end_turn_decay(combatant: Combatant) -> void:
	_decay(combatant, StatusEffectData.Decay.REMOVE_ON_TURN_END)
	_decay(combatant, StatusEffectData.Decay.DECREMENT_ON_TURN_END)
	_decay(combatant, StatusEffectData.Decay.HALVE_ON_TURN_END)


func _all_living() -> Array[Combatant]:
	var out: Array[Combatant] = []
	if not player.is_dead:
		out.append(player)
	out.append_array(living_enemies())
	return out


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
	EventBus.card_played.emit(card, targets)

	var ctx := _card_context(card, target)
	ctx.x_value = x
	_run_effects(card.data.effects, ctx)

	if card.data.type == CardData.CardType.POWER:
		pass  # Powers leave play; their effect lives on as a status.
	elif card.has_keyword(CardData.KW_EXHAUST):
		_exhaust(card)
	else:
		discard_pile.append(card)
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
	return true


## Uses a potion in combat. The caller removes it from the potion belt.
func can_use_potion(potion: PotionData, target: Combatant = null) -> String:
	if phase != Phase.PLAYER_TURN:
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
		EventBus.card_drawn.emit(card)
		fire(EffectTrigger.Timing.CARD_DRAWN, player, {"card": card})


## Manual discard from hand (Scribe effects). Triggers Footnotes.
func discard_card(card: CardInstance) -> void:
	if not hand.has(card):
		return
	hand.erase(card)
	discard_pile.append(card)
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
	EventBus.card_created.emit(card, StringName(Pile.keys()[pile].to_lower()))
	return card


func _reshuffle() -> void:
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	rng.shuffle(draw_pile, &"shuffle")
	EventBus.deck_shuffled.emit(draw_pile.size())
	fire(EffectTrigger.Timing.DECK_SHUFFLED, player)


func _exhaust(card: CardInstance) -> void:
	exhaust_pile.append(card)
	EventBus.card_exhausted.emit(card)
	fire(EffectTrigger.Timing.CARD_EXHAUSTED, player, {"card": card})


func _discard_hand() -> void:
	for card in hand.duplicate():
		if card.has_keyword(CardData.KW_RETAIN):
			EventBus.card_retained.emit(card)
			continue
		hand.erase(card)
		if card.has_keyword(CardData.KW_ETHEREAL):
			_exhaust(card)
		else:
			discard_pile.append(card)
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
	EventBus.energy_changed.emit(player.energy, get_max_energy())


func gain_energy(amount: int) -> void:
	player.energy = maxi(player.energy + amount, 0)
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
	EventBus.class_resource_changed.emit(res.id, old, player.resource_value, res.max_value)
	if actual > 0:
		fire(EffectTrigger.Timing.CLASS_RESOURCE_GAINED, player, {"amount": actual})
		if player.resource_value >= res.max_value and not res.max_triggers_at_turn_end:
			_trigger_resource_max()
	else:
		fire(EffectTrigger.Timing.CLASS_RESOURCE_SPENT, player, {"amount": -actual})
	return actual


func set_class_resource(value: int) -> void:
	change_class_resource(value - player.resource_value)


func _trigger_resource_max() -> void:
	var res := player.get_resource_data()
	EventBus.class_resource_maxed.emit(res.id)
	_run_effects(res.on_reach_max_effects, EffectContext.new(self, player, null))


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
	EventBus.damage_dealt.emit(info)

	if info.block_before > 0 and target.block == 0:
		EventBus.block_broken.emit(target)
		fire(EffectTrigger.Timing.BLOCK_BROKEN, target, {"info": info})
	if type == DamageInfo.Type.ATTACK:
		fire(EffectTrigger.Timing.ATTACKED, target, {"attacker": source, "info": info})
		if source != null:
			fire(EffectTrigger.Timing.DEALT_ATTACK_DAMAGE, source, {"info": info})
	if info.hp_lost > 0:
		fire(EffectTrigger.Timing.HP_LOST, target, {"info": info})

	if info.killed:
		_kill(target)
	elif target is EnemyCombatant:
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


func _kill(target: Combatant) -> void:
	target.hp = 0
	target.block = 0
	target.is_dead = true
	EventBus.combatant_died.emit(target)
	fire(EffectTrigger.Timing.OWNER_DIED, target)
	if target is EnemyCombatant:
		fire(EffectTrigger.Timing.ENEMY_DIED, player, {"enemy": target})
	_check_end()


func _check_end() -> void:
	if is_over() or _ending:
		return
	if player.is_dead:
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
		fire(EffectTrigger.Timing.COMBAT_END, player, {}, true)
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
	if data.skips_turn and target is EnemyCombatant:
		_emit_intent(target)
	_refresh_intents()


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
			StatusEffectData.Decay.REMOVE_ON_TURN_END:
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
	if owner == player:
		for relic in relics:
			for trigger in relic.triggers:
				if trigger.timing == timing:
					_queue_trigger(trigger, owner, &"", relic, payload, immediate)
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
	for combatant in _all_living():
		fire(timing, combatant, payload)


func _queue_trigger(trigger: EffectTrigger, owner: Combatant, status_id: StringName,
		relic: RelicData, payload: Dictionary, immediate: bool) -> void:
	if not _trigger_condition_met(trigger, payload):
		return
	if trigger.every_nth > 1:
		var key := "%d:%d" % [owner.id, trigger.get_instance_id()]
		var count: int = _trigger_counts.get(key, 0) + 1
		_trigger_counts[key] = count % trigger.every_nth
		if relic:
			EventBus.relic_counter_changed.emit(relic, count % trigger.every_nth)
		if count < trigger.every_nth:
			return
	var action := _run_trigger.bind(trigger, owner, status_id, relic, payload)
	if immediate:
		action.call()
	else:
		queue.push(action)


func _trigger_condition_met(trigger: EffectTrigger, payload: Dictionary) -> bool:
	if trigger.required_card_tag != &"":
		var card: CardInstance = payload.get("card")
		if card == null or not card.data.tags.has(trigger.required_card_tag):
			return false
	var info: DamageInfo = payload.get("info")
	match trigger.condition:
		EffectTrigger.Condition.HIT_WHILE_BLOCKING:
			return info != null and info.block_before > 0
		EffectTrigger.Condition.UNBLOCKED_HIT:
			return info != null and info.hp_lost > 0
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
	if relic:
		EventBus.relic_triggered.emit(relic)
	if status_id != &"":
		EventBus.status_triggered.emit(owner, owner.status_data[status_id])
	_run_effects(trigger.effects, ctx)
	if status_id != &"" and owner.has_status(status_id):
		var data: StatusEffectData = owner.status_data[status_id]
		match data.decay:
			StatusEffectData.Decay.DECREMENT_ON_TRIGGER:
				_set_stacks(owner, data, owner.get_stacks(status_id) - 1)
			StatusEffectData.Decay.REMOVE_ON_TRIGGER:
				remove_status(owner, status_id)


func _run_effects(effects: Array[GameEffect], ctx: EffectContext) -> void:
	for effect in effects:
		if is_over():
			return
		effect.execute(ctx)


func _flush() -> void:
	queue.flush(is_over)
	_check_end()


# =============================================================================
# Enemies
# =============================================================================

func _apply_starting_statuses(enemy: EnemyCombatant) -> void:
	for entry in enemy.data.starting_statuses:
		apply_status(enemy, entry.status, entry.stacks, enemy)


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


func _move_context(enemy: EnemyCombatant, move: EnemyMoveData) -> EffectContext:
	var ctx := EffectContext.new(self, enemy, player)
	ctx.bonus = AscensionRules.move_bonus(move, ascension)
	ctx.damage_multiplier = AscensionRules.enemy_damage_multiplier(enemy.data.tier, ascension)
	return ctx


func _execute_move(enemy: EnemyCombatant, move: EnemyMoveData) -> void:
	enemy.move_history.append(move.id)
	for move_id in enemy.cooldowns.keys():
		enemy.cooldowns[move_id] = maxi(int(enemy.cooldowns[move_id]) - 1, 0)
	if move.cooldown > 0:
		enemy.cooldowns[move.id] = move.cooldown
	if get_intent_damage(enemy).x > 0 or _is_attack_intent(move.intent):
		EventBus.attack_started.emit(enemy, [player])
	var ctx := _move_context(enemy, move)
	for effect in move.effects:
		if is_over() or enemy.is_dead:
			return
		effect.execute(ctx)


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
	_run_effects(new_phase.on_enter_effects, EffectContext.new(self, enemy, player))
	_roll_intent(enemy)
