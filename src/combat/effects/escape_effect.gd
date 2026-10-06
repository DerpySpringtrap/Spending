@tool
class_name EscapeEffect
extends GameEffect
## Enemy-only: the enemy flees the fight (Coin Mimic). If it was the last one
## standing, the fight is won, but without the escaped enemy's stolen gold.


func execute(ctx: EffectContext) -> void:
	if ctx.source is EnemyCombatant:
		ctx.combat.escape(ctx.source)
