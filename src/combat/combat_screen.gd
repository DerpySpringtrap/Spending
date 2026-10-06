extends Control
## Milestone 1 placeholder combat screen: plain Controls, no art, no animation.
##
## It reads CombatState directly after each action, which is fine while there
## is no presentation queue. The Milestone 2 screen replaces this with proper
## components that replay EventBus beats.
##
## Mouse: click a card, then click an enemy for single-target cards.
## Keyboard: 1-9/0 select a card (then 1-5 pick a target), E ends the turn,
## A auto-plays the turn, Esc cancels.

const CARD_SIZE := Vector2(190, 240)
const ENEMY_SIZE := Vector2(260, 190)
const TYPE_COLORS := {
	CardData.CardType.ATTACK: Color("#5a2a26"),
	CardData.CardType.SKILL: Color("#26405a"),
	CardData.CardType.POWER: Color("#4a2a5a"),
	CardData.CardType.STATUS: Color("#3a3a3a"),
	CardData.CardType.CURSE: Color("#2a1a2a"),
}

var combat: CombatState
var _selected_card: CardInstance
var _hover_target: Combatant
var _refresh_queued := false
var _ai := GreedyPlayerAI.new()
## [Signal, Callable] pairs connected to the global EventBus, disconnected on exit.
var _connections: Array = []

var _enemy_row: HBoxContainer
var _player_label: RichTextLabel
var _hand_row: HBoxContainer
var _piles_label: Label
var _prompt: Label
var _end_turn_button: Button
var _autoplay_button: Button
var _log: RichTextLabel
var _overlay: Control
var _overlay_label: Label
var _overlay_buttons: HBoxContainer


func _ready() -> void:
	_build_ui()
	_connect_bus()
	_start_fight()


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
	_log_line("[color=#F6B43C][b]A fight begins: %s[/b][/color]" % ", ".join(enc.enemies.map(func(e): return e.display_name)))
	combat = CombatState.create(RunState.get_class_data(), RunState.deck, RunState.hp, RunState.max_hp,
			RunState.relics, enc, RunState.ascension, RunState.rng)
	combat.start()
	_queue_refresh()


func _random_encounter() -> EncounterData:
	var options: Array[EncounterData] = []
	options.append_array(ContentDB.get_encounters(1, EncounterData.Pool.EASY))
	options.append_array(ContentDB.get_encounters(1, EncounterData.Pool.HARD))
	return RunState.rng.pick(options, &"encounters")


func _connect_bus() -> void:
	var refresh := func(_a = null, _b = null, _c = null, _d = null): _queue_refresh()
	for sig in [EventBus.energy_changed, EventBus.class_resource_changed, EventBus.card_drawn,
			EventBus.card_played, EventBus.damage_dealt, EventBus.block_gained, EventBus.block_cleared,
			EventBus.status_applied, EventBus.status_removed, EventBus.intent_changed, EventBus.combatant_died]:
		_listen(sig, refresh)
	_listen(EventBus.card_played, _on_card_played)
	_listen(EventBus.damage_dealt, _on_damage_dealt)
	_listen(EventBus.block_gained, _on_block_gained)
	_listen(EventBus.status_applied, _on_status_applied)
	_listen(EventBus.combatant_died, func(c): _log_line("[color=#999]%s dies.[/color]" % c.display_name))
	_listen(EventBus.turn_started, _on_turn_started)
	_listen(EventBus.class_resource_maxed, func(_id): _log_line("[color=#FF7A2A][b]OVERHEAT![/b][/color]"))
	_listen(EventBus.deck_shuffled, func(n): _log_line("[color=#777]Discard pile shuffled into draw pile (%d).[/color]" % n))
	_listen(EventBus.card_created, func(c, pile): _log_line("A [b]%s[/b] is added to your %s pile." % [c.data.display_name, pile]))
	_listen(EventBus.combat_ended, func(victory): _show_result.call_deferred(victory))


func _listen(sig: Signal, callable: Callable) -> void:
	sig.connect(callable)
	_connections.append([sig, callable])


func _exit_tree() -> void:
	for pair in _connections:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])
	_connections.clear()


# =============================================================================
# Input
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if combat == null or combat.is_over() or _overlay.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_select_card(null)
		accept_event()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = event.keycode
	if key == KEY_E:
		_end_turn()
	elif key == KEY_A:
		_autoplay()
	elif key >= KEY_0 and key <= KEY_9:
		var index := 9 if key == KEY_0 else key - KEY_1
		if _selected_card != null:
			var living := combat.living_enemies()
			if index < living.size():
				_on_enemy_pressed(living[index])
		elif index < combat.hand.size():
			_on_card_pressed(combat.hand[index])
	else:
		return
	accept_event()


func _on_card_pressed(card: CardInstance) -> void:
	if combat.phase != CombatState.Phase.PLAYER_TURN:
		return
	if _selected_card == card:
		_select_card(null)
		return
	if card.data.target_mode == CardData.TargetMode.SINGLE_ENEMY:
		var reason := combat.can_play(card, combat.living_enemies()[0])
		if reason != "":
			_flash_prompt(reason)
			return
		_select_card(card)
		return
	var reason := combat.can_play(card)
	if reason != "":
		_flash_prompt(reason)
		return
	combat.play_card(card)
	_select_card(null)


func _on_enemy_pressed(enemy: EnemyCombatant) -> void:
	if _selected_card == null or enemy.is_dead:
		return
	var card := _selected_card
	_select_card(null)
	combat.play_card(card, enemy)


func _select_card(card: CardInstance) -> void:
	_selected_card = card
	_prompt.text = "" if card == null else "Choose a target for %s (click an enemy or press 1-%d). Esc to cancel." % [
		card.get_display_name(), combat.living_enemies().size()]
	_queue_refresh()


func _end_turn() -> void:
	if combat.phase == CombatState.Phase.PLAYER_TURN:
		_select_card(null)
		combat.end_player_turn()


func _autoplay() -> void:
	if combat.phase == CombatState.Phase.PLAYER_TURN:
		_select_card(null)
		_ai.play_turn(combat)


func _flash_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.modulate = Color(1, 0.5, 0.5)
	var tween := create_tween()
	tween.tween_property(_prompt, "modulate", Color.WHITE, 0.6)


# =============================================================================
# Rendering
# =============================================================================

func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	if combat == null:
		return
	_refresh_enemies()
	_refresh_player()
	_refresh_hand()
	var player_turn := combat.phase == CombatState.Phase.PLAYER_TURN
	_end_turn_button.disabled = not player_turn
	_autoplay_button.disabled = not player_turn


func _refresh_enemies() -> void:
	for child in _enemy_row.get_children():
		child.queue_free()
	for i in combat.enemies.size():
		var enemy := combat.enemies[i]
		var button := Button.new()
		button.custom_minimum_size = ENEMY_SIZE
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.focus_mode = Control.FOCUS_NONE
		if enemy.is_dead:
			button.text = "%s\n\n(defeated)" % enemy.display_name
			button.disabled = true
		else:
			var lines: PackedStringArray = [
				"[%d] %s" % [i + 1, enemy.display_name],
				"HP %d / %d%s" % [enemy.hp, enemy.max_hp, ("   Block %d" % enemy.block) if enemy.block > 0 else ""],
				"",
				"Intent: " + _intent_text(enemy),
			]
			var statuses := _status_text(enemy)
			if statuses != "":
				lines.append(statuses)
			button.text = "\n".join(lines)
			if _selected_card != null:
				button.modulate = Color(1.0, 0.85, 0.5)
			button.pressed.connect(_on_enemy_pressed.bind(enemy))
			button.mouse_entered.connect(func(): _set_hover_target(enemy))
			button.mouse_exited.connect(func(): _set_hover_target(null))
		_enemy_row.add_child(button)


func _refresh_player() -> void:
	var p := combat.player
	var res := p.get_resource_data()
	var text := "[b]%s[/b]    HP [color=#E05A47]%d / %d[/color]" % [p.display_name, p.hp, p.max_hp]
	if p.block > 0:
		text += "    Block [color=#5AB0E0]%d[/color]" % p.block
	text += "\nEnergy [color=#F6D743]%d / %d[/color]" % [p.energy, combat.get_max_energy()]
	if res:
		var heat_color := "#FF5A2A" if p.resource_value >= res.max_value else res.color.to_html(false)
		text += "    %s [color=#%s]%d / %d[/color]" % [res.display_name, heat_color.trim_prefix("#"), p.resource_value, res.max_value]
		if p.resource_value >= res.max_value:
			text += "  [color=#FF5A2A](will Overheat at end of turn)[/color]"
	var statuses := _status_text(p)
	if statuses != "":
		text += "\n" + statuses
	if not combat.relics.is_empty():
		text += "\n[color=#999]Relics: %s[/color]" % ", ".join(combat.relics.map(func(r): return r.display_name))
	_player_label.text = text
	_piles_label.text = "Round %d    Draw %d    Discard %d    Exhaust %d" % [
		combat.round_number, combat.draw_pile.size(), combat.discard_pile.size(), combat.exhaust_pile.size()]


func _refresh_hand() -> void:
	for child in _hand_row.get_children():
		child.queue_free()
	for i in combat.hand.size():
		var card := combat.hand[i]
		var button := Button.new()
		button.custom_minimum_size = CARD_SIZE
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.focus_mode = Control.FOCUS_NONE
		var cost := card.get_cost()
		var cost_text := "X" if cost == CardData.COST_X else ("-" if cost == CardData.COST_UNPLAYABLE else str(cost))
		var target := _hover_target if _selected_card == card else null
		button.text = "(%s)  %s\n%s · %s\n\n%s\n\n[%d]" % [
			cost_text, card.get_display_name(),
			CardData.CardType.keys()[card.data.type].capitalize(),
			CardData.Rarity.keys()[card.data.rarity].capitalize(),
			CardText.render(card, combat, target),
			(i + 1) % 10,
		]
		var style := StyleBoxFlat.new()
		style.bg_color = TYPE_COLORS.get(card.data.type, Color("#333333"))
		style.set_corner_radius_all(8)
		style.set_border_width_all(3 if _selected_card == card else 1)
		style.border_color = Color("#F6B43C") if _selected_card == card else Color("#00000080")
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		if not combat.is_affordable(card):
			button.modulate = Color(1, 1, 1, 0.45)  # "Too expensive" dim.
		button.pressed.connect(_on_card_pressed.bind(card))
		_hand_row.add_child(button)


func _set_hover_target(enemy: Combatant) -> void:
	if _hover_target != enemy:
		_hover_target = enemy
		if _selected_card != null:
			_refresh_hand()


func _intent_text(enemy: EnemyCombatant) -> String:
	if enemy.skips_turn():
		return "Stunned"
	var move := enemy.next_move
	if move == null:
		return "?"
	var label := String(EnemyMoveData.Intent.keys()[move.intent]).capitalize()
	var dmg := combat.get_intent_damage(enemy)
	if dmg.x > 0:
		label += " %d" % dmg.x + (("x%d" % dmg.y) if dmg.y > 1 else "")
	return "%s (%s)" % [label, move.display_name]


func _status_text(c: Combatant) -> String:
	var parts: PackedStringArray = []
	for status_id in c.statuses:
		var data: StatusEffectData = c.status_data[status_id]
		if data.hidden:
			continue
		var stacks: int = c.statuses[status_id]
		parts.append(data.display_name if data.stack_mode == StatusEffectData.StackMode.FLAG else "%s %d" % [data.display_name, stacks])
	return ", ".join(parts)


# =============================================================================
# Combat log
# =============================================================================

func _log_line(text: String) -> void:
	_log.append_text(text + "\n")


func _on_turn_started(c, is_player: bool) -> void:
	if is_player:
		_log_line("\n[color=#F6B43C]— Round %d —[/color]" % combat.round_number)


func _on_card_played(card: CardInstance, targets: Array) -> void:
	var on := "" if targets.is_empty() or targets.size() > 1 else " on %s" % targets[0].display_name
	_log_line("You play [b]%s[/b]%s." % [card.get_display_name(), on])


func _on_damage_dealt(info: DamageInfo) -> void:
	var kind := "" if info.type == DamageInfo.Type.ATTACK else " (%s)" % String(DamageInfo.Type.keys()[info.type]).to_lower()
	var blocked := "" if info.blocked == 0 else ", %d blocked" % info.blocked
	_log_line("%s takes [color=#E05A47]%d[/color] damage%s%s." % [info.target.display_name, info.hp_lost, kind, blocked])


func _on_block_gained(c, amount: int, _after: int) -> void:
	_log_line("%s gains [color=#5AB0E0]%d[/color] Block." % [c.display_name, amount])


func _on_status_applied(c, status: StatusEffectData, delta: int, stacks: int) -> void:
	if delta > 0 and not status.hidden:
		_log_line("%s gains [color=#%s]%s[/color] (%d)." % [c.display_name, status.tint.to_html(false), status.display_name, stacks])


# =============================================================================
# Result
# =============================================================================

func _show_result(victory: bool) -> void:
	for child in _overlay_buttons.get_children():
		child.queue_free()
	if victory:
		var gold := 0
		for enemy in combat.enemies:
			gold += RunState.rng.get_stream(&"rewards").randi_range(enemy.data.gold_min, enemy.data.gold_max)
		RunState.set_hp(combat.player.hp)
		RunState.add_gold(gold)
		_overlay_label.text = "Victory!\n\nHP %d / %d    +%d gold (%d total)" % [RunState.hp, RunState.max_hp, gold, RunState.gold]
		_add_overlay_button("Next Fight", func(): GameManager.start_combat(_random_encounter()))
	else:
		_overlay_label.text = "Defeat.\n\nYou fell in round %d." % combat.round_number
		_add_overlay_button("New Run", func():
			RunState.clear()
			GameManager.start_debug_combat())
	_add_overlay_button("Back to Title", func():
		RunState.clear()
		GameManager.go_to_screen(&"boot"))
	_overlay.visible = true
	(_overlay_buttons.get_child(0) as Button).grab_focus()


func _add_overlay_button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(200, 56)
	button.pressed.connect(action)
	_overlay_buttons.add_child(button)


# =============================================================================
# Layout (built in code: this whole screen is replaced in Milestone 2)
# =============================================================================

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#141218")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 24)
	margin.add_child(root)

	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 14)
	root.add_child(main)

	var title := Label.new()
	title.text = "Act 1 · Placeholder combat (Milestone 1)"
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color(1, 1, 1, 0.5)
	main.add_child(title)

	_enemy_row = HBoxContainer.new()
	_enemy_row.alignment = BoxContainer.ALIGNMENT_END
	_enemy_row.add_theme_constant_override("separation", 16)
	main.add_child(_enemy_row)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(spacer)

	_player_label = RichTextLabel.new()
	_player_label.bbcode_enabled = true
	_player_label.fit_content = true
	_player_label.add_theme_font_size_override("normal_font_size", 22)
	_player_label.add_theme_font_size_override("bold_font_size", 22)
	main.add_child(_player_label)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	main.add_child(controls)
	_piles_label = Label.new()
	_piles_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(_piles_label)
	_autoplay_button = Button.new()
	_autoplay_button.text = "Auto-play Turn (A)"
	_autoplay_button.pressed.connect(_autoplay)
	controls.add_child(_autoplay_button)
	_end_turn_button = Button.new()
	_end_turn_button.text = "End Turn (E)"
	_end_turn_button.custom_minimum_size = Vector2(180, 48)
	_end_turn_button.pressed.connect(_end_turn)
	controls.add_child(_end_turn_button)

	_prompt = Label.new()
	_prompt.custom_minimum_size = Vector2(0, 28)
	main.add_child(_prompt)

	_hand_row = HBoxContainer.new()
	_hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_row.add_theme_constant_override("separation", 10)
	_hand_row.custom_minimum_size = Vector2(0, CARD_SIZE.y)
	main.add_child(_hand_row)

	var log_panel := PanelContainer.new()
	log_panel.custom_minimum_size = Vector2(440, 0)
	root.add_child(log_panel)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 16)
	_log.add_theme_font_size_override("bold_font_size", 16)
	log_panel.add_child(_log)

	_overlay = ColorRect.new()
	(_overlay as ColorRect).color = Color(0, 0, 0, 0.7)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)
	_overlay_label = Label.new()
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_label.add_theme_font_size_override("font_size", 36)
	box.add_child(_overlay_label)
	_overlay_buttons = HBoxContainer.new()
	_overlay_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_overlay_buttons.add_theme_constant_override("separation", 16)
	box.add_child(_overlay_buttons)
