@tool
class_name SummonAllyEffect
extends GameEffect
## Player-only: summons [member amount] allies (max 3 alive at once).
## [member upgraded_summon], if set, is used when the card is upgraded.

@export var summon: EnemyData
@export var upgraded_summon: EnemyData


func execute(ctx: EffectContext) -> void:
	if ctx.source != ctx.combat.player:
		return
	var data := upgraded_summon if ctx.upgraded and upgraded_summon != null else summon
	for i in maxi(ctx.amount_for(self), 1):
		if ctx.combat.summon_ally(data) == null:
			return
