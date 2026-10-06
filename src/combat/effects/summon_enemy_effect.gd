@tool
class_name SummonEnemyEffect
extends GameEffect
## Adds enemies to the fight (boss adds, "Call the Brood"). Amount = copies.

@export var enemy: EnemyData
## Never exceed this many living enemies in total.
@export var max_enemies: int = 5


func execute(ctx: EffectContext) -> void:
	if enemy == null:
		push_error("SummonEnemyEffect without an enemy")
		return
	for i in maxi(ctx.amount_for(self), 1):
		if ctx.combat.living_enemies().size() >= max_enemies:
			return
		ctx.combat.add_enemy(enemy)
