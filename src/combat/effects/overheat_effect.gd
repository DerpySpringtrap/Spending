@tool
class_name OverheatEffect
extends GameEffect
## Pyre Warden's Overheat: blast ALL enemies, take recoil, reset Heat.
## Owning [member mastery_status] (Eternal Pyre) removes the recoil and resets
## Heat to [member mastery_reset_to] instead.

@export var blast_damage: int = 12
@export var self_damage: int = 3
@export var reset_to: int = 0
@export var mastery_status: StatusEffectData
@export var mastery_reset_to: int = 5


func execute(ctx: EffectContext) -> void:
	var combat := ctx.combat
	var mastered := mastery_status != null and combat.player.has_status(mastery_status.id)
	for enemy in combat.living_enemies():
		combat.deal_damage(combat.player, enemy, blast_damage, DamageInfo.Type.OTHER)
	if combat.is_over():
		return
	if not mastered and self_damage > 0:
		combat.deal_damage(combat.player, combat.player, self_damage, DamageInfo.Type.HP_LOSS)
	if not combat.is_over():
		combat.set_class_resource(mastery_reset_to if mastered else reset_to)
