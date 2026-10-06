class_name EnemyAI
extends RefCounted
## Picks an enemy's next move.
##
## Most enemies use the data-driven rules in [method choose_by_rules]
## (opening moves, then SEQUENCE or WEIGHTED_RANDOM honouring max_consecutive,
## cooldown and min_turn). Bosses with bespoke logic subclass this, override
## [method choose_move], and set the script on EnemyPhaseData.ai_script with
## selection = SCRIPTED.


func choose_move(enemy: EnemyCombatant, combat: CombatState) -> EnemyMoveData:
	return EnemyAI.choose_by_rules(enemy, combat.rng.get_stream(&"combat"), combat.living_enemies().size() - 1)


static func choose_by_rules(enemy: EnemyCombatant, rng: RandomNumberGenerator, ally_count: int = 0) -> EnemyMoveData:
	var phase := enemy.current_phase()
	if phase == null:
		return null
	if enemy.opening_index < phase.opening_moves.size():
		var opening := phase.opening_moves[enemy.opening_index]
		enemy.opening_index += 1
		return opening
	if phase.moves.is_empty():
		return null
	if phase.selection == EnemyPhaseData.Selection.SEQUENCE:
		var move := phase.moves[enemy.sequence_index % phase.moves.size()]
		enemy.sequence_index += 1
		return move

	var legal: Array[EnemyMoveData] = []
	for move in phase.moves:
		if is_legal(enemy, move, ally_count):
			legal.append(move)
	if legal.is_empty():
		# Over-constrained data: fall back to anything with weight rather than stall.
		legal = phase.moves.duplicate()
	var total := 0.0
	for move in legal:
		total += maxf(move.weight, 0.0)
	if total <= 0.0:
		return legal[0]
	var roll := rng.randf() * total
	for move in legal:
		roll -= maxf(move.weight, 0.0)
		if roll <= 0.0:
			return move
	return legal.back()


static func is_legal(enemy: EnemyCombatant, move: EnemyMoveData, ally_count: int = 0) -> bool:
	if move.weight <= 0.0:
		return false
	if move.max_living_allies >= 0 and ally_count > move.max_living_allies:
		return false
	if move.min_turn > 0 and enemy.turns_taken + 1 < move.min_turn:
		return false
	if int(enemy.cooldowns.get(move.id, 0)) > 0:
		return false
	if move.max_consecutive > 0 and enemy.consecutive_uses(move.id) >= move.max_consecutive:
		return false
	return true
