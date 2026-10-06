class_name EnemyCombatant
extends Combatant
## An enemy instance with its AI bookkeeping (phase, history, cooldowns).

var data: EnemyData
var phase_index: int = 0
var next_move: EnemyMoveData
var move_history: Array[StringName] = []
var cooldowns: Dictionary = {}  # move id -> turns remaining
var sequence_index: int = 0
var opening_index: int = 0
var turns_taken: int = 0


func _init(p_data: EnemyData, p_hp: int) -> void:
	super(p_data.display_name, Side.ENEMY, p_hp, p_hp)
	data = p_data


func current_phase() -> EnemyPhaseData:
	if phase_index < data.phases.size():
		return data.phases[phase_index]
	return null


## How many times in a row (ending with the latest) a move was used.
func consecutive_uses(move_id: StringName) -> int:
	var count := 0
	for i in range(move_history.size() - 1, -1, -1):
		if move_history[i] != move_id:
			break
		count += 1
	return count
