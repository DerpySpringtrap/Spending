class_name GreedyPlayerAI
extends RefCounted
## A simple card-playing AI for balance simulations and the debug autoplay
## button. Each step it plays the affordable card with the best heuristic
## value until nothing worthwhile is left, then ends the turn.
##
## Deliberately a little dumb, about a casual player. Win rates from it are a
## lower bound for tuning, not a target in themselves.

const MAX_PLAYS_PER_TURN := 30


func play_turn(combat: CombatState) -> void:
	var plays := 0
	while combat.phase == CombatState.Phase.PLAYER_TURN and plays < MAX_PLAYS_PER_TURN:
		var best: CardInstance = null
		var best_target: Combatant = null
		var best_score := 0.0
		for card in combat.hand:
			if not combat.is_affordable(card):
				continue
			var target := pick_target(combat, card)
			if combat.can_play(card, target) != "":
				continue
			var value := score(combat, card, target)
			if value > best_score:
				best_score = value
				best = card
				best_target = target
		if best == null:
			break
		combat.play_card(best, best_target)
		plays += 1
	if combat.phase == CombatState.Phase.PLAYER_TURN:
		combat.end_player_turn()


## Single-target cards go to the enemy we can kill, else the weakest one.
func pick_target(combat: CombatState, card: CardInstance) -> Combatant:
	if card.data.target_mode != CardData.TargetMode.SINGLE_ENEMY:
		return null
	var best: EnemyCombatant = null
	for enemy in combat.living_enemies():
		if best == null or enemy.hp + enemy.block < best.hp + best.block:
			best = enemy
	return best


func score(combat: CombatState, card: CardInstance, target: Combatant) -> float:
	match card.data.type:
		CardData.CardType.POWER:
			return 50.0
		CardData.CardType.STATUS, CardData.CardType.CURSE:
			return 0.5  # Only worth it with spare energy (clears clutter).
	var ctx := EffectContext.new(combat, combat.player, target)
	ctx.card = card
	ctx.upgraded = card.upgraded
	ctx.x_value = combat.player.energy
	var totals := {"damage": 0.0, "block": 0.0, "other": 0.0}
	_evaluate(card.data.effects, ctx, totals)

	var incoming := 0
	for enemy in combat.living_enemies():
		var intent := combat.get_intent_damage(enemy)
		incoming += intent.x * intent.y
	var block_needed := maxi(incoming - combat.player.block, 0)
	var value: float = totals.damage + minf(totals.block, block_needed) * 1.3 + totals.other
	if target != null and totals.damage >= target.hp + target.block:
		value += 15.0
	return value


func _evaluate(effects: Array[GameEffect], ctx: EffectContext, totals: Dictionary) -> void:
	var combat := ctx.combat
	for effect in effects:
		var target_count := 1
		if effect.target == GameEffect.Target.ALL_ENEMIES:
			target_count = combat.living_enemies().size()
		if effect is DealDamageEffect:
			totals.damage += effect.preview_amount(ctx) * effect.times * target_count
		elif effect is GainBlockEffect:
			totals.block += effect.preview_amount(ctx)
		elif effect is ApplyStatusEffect:
			var stacks := ctx.amount_for(effect) * target_count
			match effect.status.id:
				&"burn", &"poison":
					totals.other += stacks * 1.5
				&"vulnerable", &"weak":
					totals.other += stacks * 4.0
				_:
					totals.other += stacks * 3.0
		elif effect is GainClassResourceEffect:
			totals.other += ctx.amount_for(effect) * 1.0
		elif effect is SpendClassResourceEffect:
			if effect.is_affordable(ctx):
				var sub: EffectContext = effect.make_preview_context(ctx)
				totals.other -= sub.x_value * 0.5
				_evaluate(effect.bonus_effects, sub, totals)
		elif effect is DrawCardsEffect:
			totals.other += ctx.amount_for(effect) * 4.0
		elif effect is GainEnergyEffect:
			totals.other += ctx.amount_for(effect) * 5.0
		elif effect is SpreadStatusEffect and ctx.chosen_target != null:
			totals.other += ctx.chosen_target.get_stacks(effect.status.id) * (combat.living_enemies().size() - 1) * 1.5
