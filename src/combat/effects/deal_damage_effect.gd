@tool
class_name DealDamageEffect
extends GameEffect
## "Deal X damage" (times N). Also used for Poison/Burn/Thorns ticks by
## choosing a non-attack damage type.

@export var damage_type: DamageInfo.Type = DamageInfo.Type.ATTACK
## The source heals for the HP damage it deals (Void Leech).
@export var lifesteal: bool = false


func _base_amount(ctx: EffectContext) -> int:
	var base := ctx.amount_for(self)
	if damage_type == DamageInfo.Type.ATTACK and ctx.damage_multiplier != 1.0:
		base = ceili(base * ctx.damage_multiplier)
	return base


## A scaled effect at 0 ("4 per phase change" with none) deals no hit at
## all, so flat bonuses like Strength or Waxing don't turn it into damage.
func _skipped(ctx: EffectContext) -> bool:
	return scale != Scale.NONE and _base_amount(ctx) <= 0


func execute(ctx: EffectContext) -> void:
	if _skipped(ctx):
		return
	var base := _base_amount(ctx)
	for i in times:
		for target_combatant in ctx.resolve_targets(self):
			var info := ctx.combat.deal_damage(ctx.source, target_combatant, base, damage_type)
			if lifesteal and info != null and info.hp_lost > 0:
				ctx.combat.heal(ctx.source, info.hp_lost)
		if ctx.combat.is_over():
			return
		if damage_type == DamageInfo.Type.ATTACK and ctx.source != null and ctx.source.is_dead:
			return


func preview_amount(ctx: EffectContext) -> int:
	if _skipped(ctx):
		return 0
	var base := _base_amount(ctx)
	if damage_type != DamageInfo.Type.ATTACK:
		return base
	var preview_target: Combatant = ctx.chosen_target if target == Target.CHOSEN else null
	return DamageCalc.attack_damage(base, ctx.source, preview_target)
