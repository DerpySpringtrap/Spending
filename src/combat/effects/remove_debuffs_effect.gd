@tool
class_name RemoveDebuffsEffect
extends GameEffect
## Cleanses every debuff from the targets (boss phase transitions, potions).


func execute(ctx: EffectContext) -> void:
	for target_combatant in ctx.resolve_targets(self):
		for status_id in target_combatant.statuses.keys():
			var data: StatusEffectData = target_combatant.status_data[status_id]
			if data.kind == StatusEffectData.Kind.DEBUFF:
				ctx.combat.remove_status(target_combatant, status_id)
