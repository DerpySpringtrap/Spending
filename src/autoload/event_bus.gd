extends Node
## Global signal hub (autoload: EventBus).
##
## Game logic only *emits*. UI, animation, VFX and audio only *listen*. No
## system calls into another across that boundary, so the presentation layer
## can be rebuilt, muted or skipped (fast mode, headless tests) without touching
## rules code.
##
## IMPORTANT: combat logic resolves instantly and emits these signals as it
## goes. The PresentationQueue (Milestone 2) records them and plays them back
## one "beat" at a time. Listeners must therefore build their visuals from the
## signal payloads (which carry post-change values such as hp_after), never by
## reading live combat state, which may already be several actions ahead.
##
## Untyped parameters are documented with the type they will carry once the
## combat classes exist (Combatant, CardInstance, DamageInfo...).

# --- Run & meta flow ----------------------------------------------------------
signal run_started(class_id: StringName, ascension: int, seed_value: int)
signal run_ended(victory: bool)
signal act_started(act: int)
signal screen_changed(screen_id: StringName)
signal map_node_selected(node)  ## MapNode
signal gold_changed(old_value: int, new_value: int)
signal run_hp_changed(old_value: int, new_value: int, max_hp: int)
signal card_added_to_deck(card)  ## CardInstance
signal card_removed_from_deck(card)  ## CardInstance
signal card_upgraded(card)  ## CardInstance
signal relic_obtained(relic: RelicData)
signal relic_triggered(relic: RelicData)  ## Flashes the relic in the relic bar.
signal relic_counter_changed(relic: RelicData, value: int)
signal potion_obtained(potion: PotionData, slot: int)
signal potion_used(potion: PotionData, slot: int)
signal potion_discarded(potion: PotionData, slot: int)
signal unlock_earned(kind: StringName, id: StringName)

# --- Combat flow --------------------------------------------------------------
signal combat_started(encounter: EncounterData)
signal combat_ended(victory: bool)
signal round_started(round_number: int)
signal turn_started(combatant, is_player: bool)  ## Combatant
signal turn_ended(combatant, is_player: bool)  ## Combatant
signal player_input_enabled(enabled: bool)
signal boss_phase_changed(boss, phase_index: int, phase: EnemyPhaseData)  ## Combatant
signal gold_stolen(enemy, amount: int)  ## Negative = returned to the player.
signal combatant_escaped(enemy)
signal combatant_spawned(combatant)  ## Minions and player summons.
signal combatant_died(combatant)

# --- Resources ----------------------------------------------------------------
signal energy_changed(current: int, max_energy: int)
signal class_resource_changed(resource_id: StringName, old_value: int, new_value: int, max_value: int)
signal class_resource_maxed(resource_id: StringName)  ## Overheat etc.
signal stance_changed(old_stance: StringName, new_stance: StringName)

# --- Cards & piles ------------------------------------------------------------
signal card_drawn(card)  ## CardInstance
signal card_played(card, targets: Array)  ## CardInstance, Array[Combatant]
signal card_discarded(card, manual: bool)  ## manual = discarded by an effect
signal card_exhausted(card)
signal card_retained(card)
signal card_created(card, pile: StringName)  ## Generated mid-combat.
signal card_cost_changed(card)
## A card effect needs the player to pick cards (CombatState.resolve_choice).
signal card_choice_requested(prompt: String, options: Array, min_count: int, max_count: int)
signal card_choice_resolved()
## Co-op: another hero's hand, energy or resource changed (refresh their panel).
signal seat_updated(seat_index: int)
## Co-op: a hero ended their turn (true) or a new turn began (false).
signal seat_ready_changed(seat_index: int, ready: bool)
## Co-op: another hero played a card.
signal ally_card_played(seat_index: int, card, targets: Array)  ## CardInstance, Array[Combatant]
## Co-op: votes or "done" flags changed (map screen refreshes its markers).
signal coop_state_changed()
signal deck_shuffled(card_count: int)  ## Discard pile shuffled into draw pile.

# --- Damage, block, statuses --------------------------------------------------
signal intent_changed(enemy, move: EnemyMoveData, preview_damage: int, hits: int)
signal attack_started(attacker, targets: Array)  ## Lunge / wind-up cue.
## info: DamageInfo with source, target, amount, blocked, hp_after, type, is_attack.
signal damage_dealt(info)
signal block_gained(combatant, amount: int, block_after: int)
signal block_broken(combatant)
signal block_cleared(combatant)  ## Block expired at the start of its owner's turn.
signal healed(combatant, amount: int, hp_after: int)
signal max_hp_changed(combatant, old_value: int, new_value: int)
signal status_applied(combatant, status: StatusEffectData, delta: int, stacks_after: int)
signal status_removed(combatant, status: StatusEffectData)
signal status_triggered(combatant, status: StatusEffectData)  ## Poison tick, Thorns...

# --- UI-wide (cross-screen) ---------------------------------------------------
signal tooltip_requested(owner: Control, title: String, body: String)
signal tooltip_cleared(owner: Control)
signal screen_shake_requested(strength: float, duration: float)
signal hit_stop_requested(duration: float)
