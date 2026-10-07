@tool
class_name StealGoldEffect
extends GameEffect
## Enemy-only: takes up to [member amount] gold from the player. The thief
## drops it all if it is killed (see CombatState.steal_gold).


func execute(ctx: EffectContext) -> void:
	if ctx.source is EnemyCombatant:
		ctx.combat.steal_gold(ctx.source, ctx.amount_for(self))


func per_player() -> bool:
	return true
