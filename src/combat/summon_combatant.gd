class_name SummonCombatant
extends EnemyCombatant
## A player-side ally (Rootmother's saplings). Defined like an enemy (an
## EnemyData with tier SUMMON, moves and intents) so it reuses the enemy move
## picker, but it fights for the player: it acts at the end of the player's
## turn and soaks single-target enemy attacks (CombatState.front_summon).


## The seat (hero) this summon fights for.
var owner_seat: int = 0


func _init(p_data: EnemyData, p_hp: int) -> void:
	super(p_data, p_hp)
	set(&"side", Combatant.Side.PLAYER)  # Direct assignment trips a GDScript enum-type quirk in sub-subclasses.
