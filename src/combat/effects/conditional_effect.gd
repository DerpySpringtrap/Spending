@tool
class_name ConditionalEffect
extends GameEffect
## "If you are in <status>, do X (otherwise Y)." A phase also counts while the
## player is in Eclipse, which has both phase bonuses.

@export var required_status: StatusEffectData
@export var effects: Array[GameEffect] = []
@export var else_effects: Array[GameEffect] = []


func is_met(ctx: EffectContext) -> bool:
	return required_status != null and ctx.combat.has_status_or_stance(ctx.source, required_status.id)


func execute(ctx: EffectContext) -> void:
	for effect in effects if is_met(ctx) else else_effects:
		if ctx.combat.is_over():
			return
		effect.execute(ctx)


func get_sub_effects() -> Array[GameEffect]:
	var out: Array[GameEffect] = effects.duplicate()
	out.append_array(else_effects)
	return out


func per_player() -> bool:
	for effect in get_sub_effects():
		if effect.per_player():
			return true
	return false
