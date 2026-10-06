extends Control
## Combat screen and presentation director.
##
## Flow: player input → CombatState (resolves instantly, emits EventBus
## signals) → this director turns each signal into a beat on the
## PresentationQueue → beats animate the views. Views are only ever updated
## from signal payloads, so what's on screen is always the replay of what
## happened, in order. Input is accepted only when the queue is idle.
##
## Controls: drag cards (mouse), or ←/→ + Accept, then ←/→ to pick a target
## (keyboard/gamepad). E / Y ends the turn, Q / LB and W / RB show the draw
## and discard piles, 1-9 play a card by position, A auto-plays (debug).

enum Mode { LOCKED, HAND, TARGETING }

const PLAY_SPOT := Vector2(0.5, 0.42)  # Fraction of the screen where played cards pause.

@onready var _world: Control = %World
@onready var _player_anchor: Control = %PlayerAnchor
@onready var _enemy_row: HBoxContainer = %EnemyRow
@onready var _hand: HandView = %HandView
@onready var _fx: CombatFX = %FxLayer
@onready var _arrow: TargetingArrow = %TargetingArrow
@onready var _energy: EnergyOrb = %EnergyOrb
@onready var _gauge: ResourceGauge = %ResourceGauge
@onready var _draw_pile: PileButton = %DrawPile
@onready var _discard_pile: PileButton = %DiscardPile
@onready var _exhaust_pile: PileButton = %ExhaustPile
@onready var _end_turn: Button = %EndTurnButton
@onready var _top_bar: TopBar = %TopBar
@onready var _banner: TurnBanner = %TurnBanner
@onready var _pile_viewer: PileViewer = %PileViewer
@onready var _result: ResultOverlay = %ResultOverlay
@onready var _message: Label = %Message

## Emitted when the fight's presentation finishes. With [member auto_route]
## (default) the screen also hands the result to GameManager.
signal finished(victory: bool)

var auto_route := true
var combat: CombatState
var queue: PresentationQueue
var _encounter: EncounterData
var _potion_slot := -1  ## Potion awaiting a target (-1 = none).
var _views: Dictionary = {}             # combatant id -> CombatantView
var _in_flight: Dictionary = {}         # card uid -> CardView (played, awaiting its pile)
var _counts := {"draw": 0, "discard": 0, "exhaust": 0}
var _mode := Mode.LOCKED
var _target_index := 0
var _targeting_card: CardInstance
var _enemy_banner_shown := false
var _ai := GreedyPlayerAI.new()
var _connections: Array = []


func _ready() -> void:
	UIStyle.speed = 2.0 if Settings.fast_mode else maxf(UIStyle.speed, 1.0)
	queue = PresentationQueue.new()
	queue.name = "PresentationQueue"
	add_child(queue)
	queue.idle.connect(_on_queue_idle)
	_fx.shake_target = _world
	_hand.arrow = _arrow
	_hand.can_pick_up = _can_pick_up
	_hand.target_at = _enemy_at
	_hand.play_requested.connect(_on_play_requested)
	_hand.target_changed.connect(_on_drag_target_changed)
	_hand.drag_cancelled.connect(func(_c): _clear_highlights())
	_hand.rejected.connect(func(_c, reason): _show_message(reason))
	_end_turn.pressed.connect(_end_player_turn)
	_draw_pile.pile_name = "Draw"
	_discard_pile.pile_name = "Discard"
	_exhaust_pile.pile_name = "Exhaust"
	_exhaust_pile.accent = UIStyle.BURN
	_draw_pile.pressed.connect(_open_pile.bind(&"draw"))
	_discard_pile.pressed.connect(_open_pile.bind(&"discard"))
	_exhaust_pile.pressed.connect(_open_pile.bind(&"exhaust"))
	_pile_viewer.closed.connect(_on_queue_idle)
	_top_bar.potion_activated.connect(_on_potion)
	_top_bar.potion_discard_requested.connect(_on_potion_discard)
	_top_bar.deck_pressed.connect(func():
		if _can_act():
			_pile_viewer.open("Your Deck", RunState.deck, Callable(), true))
	_connect_bus()
	_start_fight()


func _exit_tree() -> void:
	for pair in _connections:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])
	_connections.clear()
	Engine.time_scale = 1.0


# =============================================================================
# Setup
# =============================================================================

func _start_fight() -> void:
	if not RunState.active:
		RunState.start(ContentDB.get_character_class(&"pyre_warden"), 0, randi())
	var enc := GameManager.pending_encounter
	GameManager.pending_encounter = null
	if enc == null:
		enc = _random_encounter()
	_encounter = enc
	combat = CombatState.create(RunState.get_class_data(), RunState.deck, RunState.hp, RunState.max_hp,
			RunState.relics, enc, RunState.ascension, RunState.rng)
	_top_bar.refresh()
	_top_bar.set_location("Act %d · %s" % [RunState.act, String(EncounterData.Pool.keys()[enc.pool]).capitalize()])
	_gauge.setup(combat.player.get_resource_data(), 0)
	_energy.set_energy(0, combat.get_max_energy())
	_counts.draw = combat.draw_pile.size()
	_update_piles()
	_spawn_view(combat.player, _player_anchor)
	for enemy in combat.enemies:
		_spawn_view(enemy, _enemy_row)
	_start_music(enc)
	for enemy in combat.enemies:
		if enemy.data.has_intro_cinematic:
			var boss := enemy
			queue.push(&"intro", 0, 1.7, func():
				AudioManager.play(&"boss_intro", 0.0)
				_banner.show_banner(boss.display_name.to_upper(), UIStyle.GOLD, 1.0)
				_fx.shake(6)
				_view(boss).play_cast())
	combat.start()


func _start_music(enc: EncounterData) -> void:
	match enc.pool:
		EncounterData.Pool.BOSS:
			AudioManager.play_music_id(&"boss", 0.8)
		EncounterData.Pool.ELITE:
			AudioManager.play_music_id(&"elite", 0.8)
		_:
			AudioManager.play_music_id(&"combat", 0.8)
	AudioManager.play_ambience_id(&"swamp" if RunState.act == 1 else &"crypt")


func _spawn_view(c: Combatant, parent: Control) -> void:
	var view := CombatantView.new().setup(c)
	var slot := _free_enemy_slot() if parent == _enemy_row else -1
	parent.add_child(view)
	if slot >= 0:
		parent.move_child(view, slot)
	_views[c.id] = view
	view.gui_input.connect(func(event):
		if _potion_slot >= 0 and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not c.is_dead:
			_use_potion(_potion_slot, c))
	if parent == _enemy_row:
		view.modulate.a = 0.0
		var t := view.create_tween()
		t.tween_interval(UIStyle.dur(0.1 * _views.size()))
		t.tween_property(view, "modulate:a", 1.0, UIStyle.dur(0.35))


## Summons take over a defeated enemy's slot (e.g. Broodlings reappear beside
## the Matriarch) instead of being appended to the end of the row, which
## would shove the boss sideways. The dead view moves to a hidden holder so
## anything still referencing it keeps working. Returns -1 if no slot is free.
func _free_enemy_slot() -> int:
	for child in _enemy_row.get_children():
		if child is CombatantView and child.is_dead_shown():
			var index := child.get_index()
			_enemy_row.remove_child(child)
			_graveyard().add_child(child)
			return index
	return -1


func _graveyard() -> Control:
	var holder := get_node_or_null("Graveyard") as Control
	if holder == null:
		holder = Control.new()
		holder.name = "Graveyard"
		holder.visible = false
		add_child(holder)
	return holder


## Living enemies in on-screen order (left to right), for keyboard targeting.
func _enemies_on_screen() -> Array[EnemyCombatant]:
	var living := combat.living_enemies()
	living.sort_custom(func(a, b): return _view(a).get_index() < _view(b).get_index())
	return living


func _random_encounter() -> EncounterData:
	var options: Array[EncounterData] = []
	options.append_array(ContentDB.get_encounters(1, EncounterData.Pool.EASY))
	options.append_array(ContentDB.get_encounters(1, EncounterData.Pool.HARD))
	return RunState.rng.pick(options, &"encounters")


func _listen(sig: Signal, callable: Callable) -> void:
	sig.connect(callable)
	_connections.append([sig, callable])


func _connect_bus() -> void:
	_listen(EventBus.turn_started, _on_turn_started)
	_listen(EventBus.energy_changed, _on_energy_changed)
	_listen(EventBus.class_resource_changed, _on_resource_changed)
	_listen(EventBus.class_resource_maxed, _on_resource_maxed)
	_listen(EventBus.card_drawn, _on_card_drawn)
	_listen(EventBus.deck_shuffled, _on_deck_shuffled)
	_listen(EventBus.card_played, _on_card_played)
	_listen(EventBus.card_discarded, _on_card_discarded)
	_listen(EventBus.card_exhausted, _on_card_exhausted)
	_listen(EventBus.card_created, _on_card_created)
	_listen(EventBus.attack_started, _on_attack_started)
	_listen(EventBus.damage_dealt, _on_damage_dealt)
	_listen(EventBus.block_gained, _on_block_gained)
	_listen(EventBus.block_broken, _on_block_broken)
	_listen(EventBus.block_cleared, _on_block_cleared)
	_listen(EventBus.healed, _on_healed)
	_listen(EventBus.status_applied, _on_status_applied)
	_listen(EventBus.status_removed, _on_status_removed)
	_listen(EventBus.status_triggered, _on_status_triggered)
	_listen(EventBus.intent_changed, _on_intent_changed)
	_listen(EventBus.combatant_died, _on_combatant_died)
	_listen(EventBus.relic_triggered, _on_relic_triggered)
	_listen(EventBus.combat_ended, _on_combat_ended)
	_listen(EventBus.combatant_spawned, _on_combatant_spawned)


func _on_combatant_spawned(c: Combatant) -> void:
	if c is EnemyCombatant:
		queue.push(&"spawn", c.id, 0.35, func():
			_spawn_view(c, _enemy_row)
			AudioManager.play(&"summon")
			_fx.burst(_view(c).hit_point(), Color("#6E8A4A"), 20, 220, 300))


# =============================================================================
# Beats: one handler per EventBus signal (see docs/HOOKS_AND_ASSETS.md)
# =============================================================================

func _view(c: Combatant) -> CombatantView:
	return _views.get(c.id) if c != null else null


func _on_turn_started(c: Combatant, is_player: bool) -> void:
	if is_player:
		_enemy_banner_shown = false
		queue.push(&"banner", 0, 0.75, func():
			AudioManager.play(&"turn_player", 0.0)
			_banner.show_banner("Your Turn"))
	elif not _enemy_banner_shown:
		_enemy_banner_shown = true
		queue.push(&"banner", 0, 0.6, func():
			AudioManager.play(&"turn_enemy", 0.0)
			_banner.show_banner("Enemy Turn", UIStyle.DAMAGE.lightened(0.2), 0.3))


func _on_energy_changed(current: int, max_energy: int) -> void:
	queue.push(PresentationQueue.INSTANT, 0, 0.0, func(): _energy.set_energy(current, max_energy))


func _on_resource_changed(_id: StringName, old: int, new_value: int, max_value: int) -> void:
	queue.push(&"resource", 0, 0.08, func():
		if new_value > old:
			AudioManager.play(&"stoke", 0.08)
		_gauge.set_value(new_value, max_value))


func _on_resource_maxed(_id: StringName) -> void:
	queue.push(&"overheat", 0, 0.6, func():
		_gauge.flash()
		AudioManager.play(&"overheat")
		_banner.show_banner("Overheat!", UIStyle.BURN, 0.25)
		_fx.shake(16)
		_fx.burst(_view(combat.player).hit_point(), UIStyle.BURN, 40, 520, -200))


func _on_card_drawn(card: CardInstance) -> void:
	queue.push(&"draw", card.uid, 0.08, func(i: int):
		_counts.draw -= 1
		_update_piles()
		if i < 3:
			AudioManager.play(&"card_draw", 0.1)
		var view := CardView.new().setup(card)
		view.modulate.a = 0.0
		_hand.add_card(view, _draw_pile.center_global())
		view.create_tween().tween_property(view, "modulate:a", 1.0, UIStyle.dur(0.12)).set_delay(UIStyle.dur(0.02 * i)))


func _on_deck_shuffled(count: int) -> void:
	queue.push(&"shuffle", 0, 0.4, func():
		AudioManager.play(&"shuffle")
		for k in mini(count, 6):
			_fly_card_back(_discard_pile.center_global(), _draw_pile.center_global(), k * 0.04)
		_counts.draw = count
		_counts.discard = 0
		_update_piles())


func _on_card_played(card: CardInstance, _targets: Array) -> void:
	var is_power := card.data.type == CardData.CardType.POWER
	var is_attack := card.data.type == CardData.CardType.ATTACK
	queue.push(&"play", card.uid, 0.3 if not is_power else 0.45, func():
		var view := _take_from_hand(card)
		_in_flight[card.uid] = view
		AudioManager.play(&"card_play")
		if card.data.plays_class_motif:
			AudioManager.play(StringName("motif_%s" % combat.player.class_data.id), 0.0)
		var player_view := _view(combat.player)
		if is_attack:
			player_view.play_attack()
		else:
			player_view.play_cast()
		var t := view.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if is_power:
			_in_flight.erase(card.uid)
			var dest := player_view.hit_point() - view.pivot_offset
			t.tween_property(view, "global_position", dest, UIStyle.dur(0.4))
			t.tween_property(view, "scale", Vector2(0.15, 0.15), UIStyle.dur(0.4))
			t.tween_property(view, "modulate", Color(2, 1.6, 1.2, 0.0), UIStyle.dur(0.4))
			t.chain().tween_callback(func():
				_fx.burst(player_view.hit_point(), UIStyle.GOLD, 24, 300, -100)
				view.queue_free())
		else:
			var spot := get_viewport_rect().size * PLAY_SPOT
			t.tween_property(view, "global_position", spot - view.pivot_offset + Vector2(0, CardView.SIZE.y / 2), UIStyle.dur(0.22))
			t.tween_property(view, "rotation", 0.0, UIStyle.dur(0.22))
			t.tween_property(view, "scale", Vector2(1.1, 1.1), UIStyle.dur(0.22)))


func _on_card_discarded(card: CardInstance, _manual: bool) -> void:
	queue.push(&"discard", card.uid, 0.14, func(i: int):
		var view: CardView = _in_flight.get(card.uid)
		_in_flight.erase(card.uid)
		if view == null:
			view = _take_from_hand(card)
		if i == 0:
			AudioManager.play(&"card_discard", 0.1)
		_fly_to_pile(view, _discard_pile, i * 0.03, func():
			_counts.discard += 1
			_update_piles()))


func _on_card_exhausted(card: CardInstance) -> void:
	queue.push(&"exhaust", card.uid, 0.35, func():
		var view: CardView = _in_flight.get(card.uid)
		_in_flight.erase(card.uid)
		if view == null:
			view = _take_from_hand(card)
		_counts.exhaust += 1
		_update_piles()
		AudioManager.play(&"card_exhaust")
		var t := view.create_tween().set_parallel(true)
		t.tween_property(view, "modulate", Color(1.6, 0.7, 0.3, 0.0), UIStyle.dur(0.35))
		t.tween_property(view, "position:y", view.position.y - 60, UIStyle.dur(0.35))
		t.chain().tween_callback(view.queue_free)
		_fx.burst(view.global_position + view.pivot_offset - Vector2(0, CardView.SIZE.y * view.scale.y / 2), UIStyle.BURN, 26, 200, -260))


func _on_card_created(card: CardInstance, pile: StringName) -> void:
	queue.push(&"create", card.uid, 0.5, func():
		var view := CardView.new().setup(card)
		AudioManager.play(&"card_create")
		_fx.add_child(view)
		var center := get_viewport_rect().size * Vector2(0.5, 0.4)
		view.global_position = center - view.size / 2
		view.pivot_offset = view.size / 2
		view.scale = Vector2(0.2, 0.2)
		var t := view.create_tween()
		t.tween_property(view, "scale", Vector2.ONE, UIStyle.dur(0.2)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_interval(UIStyle.dur(0.25))
		t.tween_callback(_route_created_card.bind(view, pile)))


func _route_created_card(view: CardView, pile: StringName) -> void:
	view.pivot_offset = Vector2(CardView.SIZE.x / 2, CardView.SIZE.y)
	if pile == &"hand":
		_hand.add_card(view, view.global_position + view.pivot_offset)
		return
	var key := "discard"
	var button := _discard_pile
	if pile == &"draw":
		key = "draw"
		button = _draw_pile
	elif pile == &"exhaust":
		key = "exhaust"
		button = _exhaust_pile
	_fly_to_pile(view, button, 0.0, func():
		_counts[key] += 1
		_update_piles())


func _on_attack_started(attacker: Combatant, _targets: Array) -> void:
	if attacker is EnemyCombatant:
		queue.push(&"lunge", attacker.id, 0.2, func():
			AudioManager.play(&"enemy_windup", 0.08)
			_view(attacker).play_attack())


func _on_damage_dealt(info: DamageInfo) -> void:
	var big := info.type == DamageInfo.Type.ATTACK and info.amount >= 15
	queue.push(&"hit", info.target.id, 0.34 if big else 0.24, func():
		var view := _view(info.target)
		if view == null:
			return
		view.set_hp(info.hp_after, info.target.max_hp)
		view.set_block(info.block_after)
		var at := view.hit_point()
		_play_hit_sound(info, big)
		match info.type:
			DamageInfo.Type.POISON:
				_fx.burst(at, UIStyle.POISON, 14, 120, 600, 60.0, 1.0, Vector2.DOWN)
			DamageInfo.Type.BURN:
				_fx.burst(at, UIStyle.BURN, 22, 260, -380, 50.0)
			_:
				_fx.burst(at, Color(1, 0.9, 0.75), 14 if not big else 28, 380, 600)
		if info.hp_lost > 0:
			view.play_hurt()
			view.flash()
			_fx.number(view.head_point(), str(info.hp_lost), UIStyle.damage_color(info.type), big)
			if info.type == DamageInfo.Type.ATTACK or info.type == DamageInfo.Type.OTHER:
				_fx.shake(clampf(info.hp_lost * 0.6, 3.0, 18.0))
		elif info.blocked > 0:
			_fx.number(view.head_point(), "Blocked", UIStyle.BLOCK)
			_fx.burst(at, UIStyle.BLOCK, 12, 260, 300)
		if big:
			_fx.hit_stop(0.08)
		if info.target == combat.player:
			_top_bar.set_hp(info.hp_after, info.target.max_hp))


func _play_hit_sound(info: DamageInfo, big: bool) -> void:
	match info.type:
		DamageInfo.Type.POISON:
			AudioManager.play(&"poison_tick", 0.1)
		DamageInfo.Type.BURN:
			AudioManager.play(&"burn_tick", 0.1)
		_:
			if info.hp_lost <= 0 and info.blocked > 0:
				AudioManager.play(&"block_gain", 0.1, 2.0)
			else:
				AudioManager.play(&"hit_heavy" if big else &"hit", 0.08)


func _on_block_gained(c: Combatant, amount: int, block_after: int) -> void:
	queue.push(&"block", c.id, 0.16, func():
		AudioManager.play(&"block_gain", 0.08)
		var view := _view(c)
		view.set_block(block_after)
		_fx.number(view.head_point() + Vector2(0, 30), "+%d" % amount, UIStyle.BLOCK)
		_fx.burst(view.hit_point(), UIStyle.BLOCK, 10, 160, 0, 180.0, 0.8))


func _on_block_broken(c: Combatant) -> void:
	queue.push(PresentationQueue.INSTANT, c.id, 0.0, func():
		AudioManager.play(&"block_break")
		_fx.burst(_view(c).hit_point(), UIStyle.BLOCK.lightened(0.3), 20, 420, 700))


func _on_block_cleared(c: Combatant) -> void:
	queue.push(PresentationQueue.INSTANT, c.id, 0.0, func(): _view(c).set_block(0))


func _on_healed(c: Combatant, amount: int, hp_after: int) -> void:
	queue.push(&"heal", c.id, 0.22, func():
		AudioManager.play(&"heal")
		var view := _view(c)
		view.set_hp(hp_after, c.max_hp)
		_fx.number(view.head_point(), "+%d" % amount, UIStyle.HEAL)
		_fx.burst(view.hit_point(), UIStyle.HEAL, 16, 140, -200)
		if c == combat.player:
			_top_bar.set_hp(hp_after, c.max_hp))


func _on_status_applied(c: Combatant, status: StatusEffectData, delta: int, stacks: int) -> void:
	if delta > 0:
		var sound := &"status_buff" if status.kind == StatusEffectData.Kind.BUFF else &"status_debuff"
		queue.push(&"status", c.id, 0.14, func(i: int):
			if i == 0:
				AudioManager.play(sound, 0.08)
			var view := _view(c)
			view.set_status(status, stacks, true)
			_fx.burst(view.hit_point(), status.tint, 12, 180, -60, 180.0, 0.9))
	else:
		queue.push(PresentationQueue.INSTANT, c.id, 0.0, func(): _view(c).set_status(status, stacks, false))


func _on_status_removed(c: Combatant, status: StatusEffectData) -> void:
	queue.push(PresentationQueue.INSTANT, c.id, 0.0, func(): _view(c).remove_status(status))


func _on_status_triggered(c: Combatant, status: StatusEffectData) -> void:
	queue.push(&"proc", c.id, 0.12, func(): _view(c).pulse_status(status.id))


func _on_intent_changed(enemy: Combatant, move: EnemyMoveData, damage: int, hits: int) -> void:
	queue.push(PresentationQueue.INSTANT, enemy.id, 0.0, func(): _view(enemy).set_intent(move, damage, hits))


func _on_combatant_died(c: Combatant) -> void:
	queue.push(&"death", c.id, 0.55, func():
		AudioManager.play(&"death")
		var view := _view(c)
		view.play_death()
		_fx.burst(view.hit_point(), Color(0.85, 0.8, 0.75), 40, 260, -120, 180.0, 1.2))


func _on_relic_triggered(relic: RelicData) -> void:
	queue.push(PresentationQueue.INSTANT, 0, 0.0, func(): _top_bar.flash_relic(relic.id))


func _on_combat_ended(victory: bool) -> void:
	queue.push(&"end", 0, 0.5, func():
		_clear_highlights()
		_hand.end_keyboard_targeting(false)
		_hand.create_tween().tween_property(_hand, "modulate:a", 0.0, UIStyle.dur(0.3))
		if victory:
			AudioManager.play(&"victory", 0.0, -6.0)
			_view(combat.player).play_victory()
			var view_size := get_viewport_rect().size
			for k in 5:
				_fx.burst(Vector2(view_size.x * (0.15 + k * 0.175), -20), Color.from_hsv(randf(), 0.6, 1.0), 30, 300, 500, 60.0, 1.0, Vector2.DOWN))
	queue.push(&"result", 0, 0.0, func(): _show_result(victory))


# =============================================================================
# Card motion helpers
# =============================================================================

func _take_from_hand(card: CardInstance) -> CardView:
	var view := _hand.take_card(card)
	if view == null:
		view = CardView.new().setup(card)
		_fx.add_child(view)
		view.global_position = get_viewport_rect().size * Vector2(0.5, 0.8)
	else:
		view.reparent(_fx, true)
	return view


func _fly_to_pile(view: CardView, pile: PileButton, delay: float, on_arrive: Callable) -> void:
	var dest := pile.center_global() - view.pivot_offset + Vector2(0, CardView.SIZE.y * 0.1)
	var t := view.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(view, "global_position", dest, UIStyle.dur(0.3)).set_delay(UIStyle.dur(delay))
	t.tween_property(view, "scale", Vector2(0.2, 0.2), UIStyle.dur(0.3)).set_delay(UIStyle.dur(delay))
	t.tween_property(view, "rotation", 0.6, UIStyle.dur(0.3)).set_delay(UIStyle.dur(delay))
	t.chain().tween_callback(func():
		on_arrive.call()
		view.queue_free())


func _fly_card_back(from: Vector2, to: Vector2, delay: float) -> void:
	var back := CardView.new()
	back.face_down = true
	_fx.add_child(back)
	back.scale = Vector2(0.25, 0.25)
	var lift := Vector2(0, CardView.SIZE.y * 0.125)
	back.global_position = from - back.pivot_offset + lift
	var t := back.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	var start := back.global_position
	var end := to - back.pivot_offset + lift
	var ctrl := (start + end) / 2 + Vector2(0, -260)
	t.tween_method(func(k: float): back.global_position = start.lerp(ctrl, k).lerp(ctrl.lerp(end, k), k), 0.0, 1.0, UIStyle.dur(0.35)).set_delay(UIStyle.dur(delay))
	t.tween_property(back, "rotation", TAU, UIStyle.dur(0.35)).set_delay(UIStyle.dur(delay))
	t.chain().tween_callback(back.queue_free)


func _update_piles() -> void:
	_draw_pile.count = _counts.draw
	_discard_pile.count = _counts.discard
	_exhaust_pile.count = _counts.exhaust
	_exhaust_pile.visible = _counts.exhaust > 0


# =============================================================================
# Input
# =============================================================================

func _can_act() -> bool:
	return combat != null and combat.phase == CombatState.Phase.PLAYER_TURN and not queue.is_busy() \
			and not _pile_viewer.visible and not _result.visible and _potion_slot < 0


func _on_queue_idle() -> void:
	if combat == null or combat.is_over():
		_set_mode(Mode.LOCKED)
		return
	if _can_act():
		if _mode == Mode.LOCKED:
			_set_mode(Mode.HAND)
		_refresh_hand()
	else:
		_set_mode(Mode.LOCKED)


func _set_mode(mode: Mode) -> void:
	_mode = mode
	_end_turn.disabled = combat == null or combat.phase != CombatState.Phase.PLAYER_TURN
	if mode != Mode.TARGETING:
		_targeting_card = null


## Re-renders card text with live numbers and dims unaffordable cards. Only
## while idle, when live state equals what's shown.
func _refresh_hand(target: Combatant = null, for_card: CardInstance = null) -> void:
	var any_playable := false
	for view in _hand.get_views():
		var t := target if view.card == for_card else null
		view.set_description(CardText.render(view.card, combat, t, true))
		view.affordable = combat.is_affordable(view.card)
		view.display_cost = view.card.get_cost()
		any_playable = any_playable or view.affordable
	# Nudge the player toward End Turn when nothing is playable.
	_end_turn.modulate = Color(1.15, 1.15, 1.15) if not any_playable and _mode != Mode.LOCKED else Color.WHITE


func _can_pick_up(card: CardInstance) -> String:
	if not _can_act():
		return "Wait..."
	if not combat.is_affordable(card):
		return "Not enough energy" if card.data.is_playable_type() else "This card can't be played"
	return ""


func _enemy_at(global_pos: Vector2) -> Combatant:
	for enemy in combat.living_enemies():
		var view := _view(enemy)
		if view and view.get_global_rect().has_point(global_pos):
			return enemy
	return null


func _on_drag_target_changed(card: CardInstance, target: Combatant, armed: bool) -> void:
	_clear_highlights()
	if card.data.target_mode == CardData.TargetMode.SINGLE_ENEMY and target:
		_view(target).targeted = true
	elif card.data.target_mode == CardData.TargetMode.ALL_ENEMIES and armed:
		for enemy in combat.living_enemies():
			_view(enemy).targeted = true
	_refresh_hand(target, card)


func _clear_highlights() -> void:
	for view in _views.values():
		view.targeted = false


func _on_play_requested(card: CardInstance, target: Combatant) -> void:
	_clear_highlights()
	var reason := combat.can_play(card, target)
	if reason != "" or queue.is_busy():
		_hand.return_card(card)
		_show_message(reason if reason != "" else "Wait...")
		return
	_set_mode(Mode.LOCKED)
	EventBus.tooltip_cleared.emit(null)
	combat.play_card(card, target)


func _end_player_turn() -> void:
	if not _can_act() or _hand.is_dragging():
		return
	if _mode == Mode.TARGETING:
		_hand.end_keyboard_targeting(false)
	_set_mode(Mode.LOCKED)
	_clear_highlights()
	combat.end_player_turn()


func _autoplay() -> void:
	if _can_act() and not _hand.is_dragging():
		_set_mode(Mode.LOCKED)
		_ai.play_turn(combat)


func _unhandled_input(event: InputEvent) -> void:
	if not _can_act() or _hand.is_dragging():
		return
	var handled := true
	if event.is_action_pressed("view_draw"):
		_open_pile(&"draw")
	elif event.is_action_pressed("view_discard"):
		_open_pile(&"discard")
	elif _mode == Mode.HAND:
		handled = _hand_input(event)
	elif _mode == Mode.TARGETING:
		handled = _targeting_input(event)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _hand_input(event: InputEvent) -> bool:
	if event.is_action_pressed("end_turn"):
		_end_player_turn()
	elif event.is_action_pressed("ui_left"):
		_hand.move_focus(-1)
	elif event.is_action_pressed("ui_right"):
		_hand.move_focus(1)
	elif event.is_action_pressed("ui_accept"):
		var card := _hand.focused_card()
		if card:
			_activate(card)
		else:
			_hand.move_focus(1)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		if key == KEY_A:
			_autoplay()
		elif key >= KEY_1 and key <= KEY_9:
			var index := key - KEY_1
			if index < combat.hand.size():
				_hand.set_focus(index)
				_activate(_hand.focused_card())
		else:
			return false
	else:
		return false
	return true


func _activate(card: CardInstance) -> void:
	var reason := _can_pick_up(card)
	if reason != "":
		_hand.return_card(card)
		_show_message(reason)
		return
	if card.data.target_mode == CardData.TargetMode.SINGLE_ENEMY:
		_set_mode(Mode.TARGETING)
		_targeting_card = card
		_target_index = 0
		_hand.begin_keyboard_targeting(card)
		_point_keyboard_target()
	else:
		_on_play_requested(card, null)


func _targeting_input(event: InputEvent) -> bool:
	var living := _enemies_on_screen()
	if event.is_action_pressed("ui_left"):
		_target_index = wrapi(_target_index - 1, 0, living.size())
		_point_keyboard_target()
	elif event.is_action_pressed("ui_right"):
		_target_index = wrapi(_target_index + 1, 0, living.size())
		_point_keyboard_target()
	elif event.is_action_pressed("ui_accept"):
		var card := _targeting_card
		var target: Combatant = living[_target_index] if _target_index < living.size() else null
		_hand.end_keyboard_targeting(true)
		_set_mode(Mode.HAND)
		_on_play_requested(card, target)
	elif event.is_action_pressed("ui_cancel"):
		_hand.end_keyboard_targeting(false)
		_set_mode(Mode.HAND)
		_clear_highlights()
		_refresh_hand()
	elif event is InputEventKey and event.pressed and event.keycode >= KEY_1 and event.keycode <= KEY_9:
		var index: int = event.keycode - KEY_1
		if index < living.size():
			_target_index = index
			_point_keyboard_target()
	else:
		return false
	return true


func _point_keyboard_target() -> void:
	var living := _enemies_on_screen()
	if living.is_empty():
		return
	_target_index = clampi(_target_index, 0, living.size() - 1)
	var target := living[_target_index]
	_clear_highlights()
	_view(target).targeted = true
	_hand.point_keyboard_arrow(_view(target).hit_point())
	_refresh_hand(target, _targeting_card)


func _open_pile(which: StringName) -> void:
	if combat == null or (_mode == Mode.TARGETING):
		return
	var render := func(card: CardInstance) -> String: return CardText.render(card, combat, null, true)
	match which:
		&"draw":
			_pile_viewer.open("Draw Pile", combat.draw_pile, render, true)
		&"discard":
			_pile_viewer.open("Discard Pile", combat.discard_pile, render)
		&"exhaust":
			_pile_viewer.open("Exhausted", combat.exhaust_pile, render)


func _show_message(text: String) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	var t := _message.create_tween()
	t.tween_interval(0.8)
	t.tween_property(_message, "modulate:a", 0.0, 0.4)


# =============================================================================
# Result
# =============================================================================

func _show_result(victory: bool) -> void:
	if victory:
		_banner.show_banner("Victory", UIStyle.GOLD, 0.6)
		get_tree().create_timer(UIStyle.dur(1.2)).timeout.connect(func(): _finish(true))
	else:
		_result.show_result("Defeat", UIStyle.DAMAGE, "You fell in round %d against %s." % [combat.round_number, _encounter_name()], [
			["Continue", func(): _finish(false)],
		])


func _finish(victory: bool) -> void:
	finished.emit(victory)
	if not auto_route:
		return
	if victory:
		GameManager.on_combat_won(combat.player.hp)
	else:
		RunState.run_stats["killed_by"] = _encounter_name()
		GameManager.on_combat_lost()


func _encounter_name() -> String:
	for enemy in combat.enemies:
		if enemy.data.tier == EnemyData.Tier.BOSS or enemy.data.tier == EnemyData.Tier.ELITE:
			return enemy.display_name
	return combat.enemies[0].display_name if not combat.enemies.is_empty() else "the swamp"


# =============================================================================
# Potions
# =============================================================================

func _on_potion(slot: int) -> void:
	var potion: PotionData = RunState.potions[slot]
	if potion == null:
		return
	if _potion_slot >= 0:
		_cancel_potion()
		return
	if not _can_act() or _hand.is_dragging():
		_show_message("Wait...")
		return
	if potion.target_mode == CardData.TargetMode.SINGLE_ENEMY:
		_potion_slot = slot
		_show_message("Choose a target for %s" % potion.display_name)
		for enemy in combat.living_enemies():
			_view(enemy).targeted = true
		set_process(true)
	else:
		_use_potion(slot, null)


func _use_potion(slot: int, target: Combatant) -> void:
	var potion: PotionData = RunState.potions[slot]
	_potion_slot = -1
	_arrow.hide_arrow()
	_clear_highlights()
	if potion == null or combat.can_use_potion(potion, target) != "":
		return
	RunState.remove_potion(slot)
	EventBus.potion_used.emit(potion, slot)
	_top_bar.refresh()
	_set_mode(Mode.LOCKED)
	var icon := _top_bar.potion_icon(slot)
	var from := icon.center_global() if icon else Vector2(400, 40)
	queue.push(&"potion", 0, 0.3, func():
		AudioManager.play(&"potion")
		_fx.burst(from, potion.liquid_color, 24, 260, 300)
		_view(combat.player).play_cast())
	combat.use_potion(potion, target)
	if not queue.is_busy():
		_on_queue_idle()


func _cancel_potion() -> void:
	_potion_slot = -1
	_arrow.hide_arrow()
	_clear_highlights()


func _on_potion_discard(slot: int) -> void:
	if _potion_slot >= 0:
		_cancel_potion()
	var potion: PotionData = RunState.remove_potion(slot)
	EventBus.potion_discarded.emit(potion, slot)
	_top_bar.refresh()


func _process(_delta: float) -> void:
	if _potion_slot >= 0:
		var icon := _top_bar.potion_icon(_potion_slot)
		if icon:
			var mouse := get_global_mouse_position()
			_arrow.show_between(icon.center_global() + Vector2(0, 20), mouse, _enemy_at(mouse) != null)


func _input(event: InputEvent) -> void:
	if _potion_slot < 0:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		_cancel_potion()
		get_viewport().set_input_as_handled()
