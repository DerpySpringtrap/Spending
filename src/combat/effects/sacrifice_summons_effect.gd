@tool
class_name SacrificeSummonsEffect
extends GameEffect
## Destroys all living summons, then runs [member then_effects] with X = the
## number sacrificed (Elder Treant: "Sacrifice all summons. Summon a Treant
## that gains 5 max HP per summon sacrificed").

@export var then_effects: Array[GameEffect] = []


func execute(ctx: EffectContext) -> void:
	var count := ctx.combat.sacrifice_summons()
	var sub := ctx.duplicate_context()
	sub.x_value = count
	for effect in then_effects:
		if ctx.combat.is_over():
			return
		effect.execute(sub)


func get_sub_effects() -> Array[GameEffect]:
	return then_effects


func per_player() -> bool:
	return true
