@tool
class_name RewindEffect
extends GameEffect
## Enemy-only: heals back to the HP it had at the start of its turn
## [member amount] turns ago (Astral Weaver). Never lowers HP.


func execute(ctx: EffectContext) -> void:
	var enemy := ctx.source as EnemyCombatant
	if enemy == null or enemy.is_dead:
		return
	var turns := maxi(ctx.amount_for(self), 1)
	var history := enemy.hp_history
	if history.size() <= turns:
		return
	var target_hp: int = history[history.size() - 1 - turns]
	if target_hp > enemy.hp:
		ctx.combat.heal(enemy, target_hp - enemy.hp)
