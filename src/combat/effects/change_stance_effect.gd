@tool
class_name ChangeStanceEffect
extends GameEffect
## Moonblade phases: Wax / Wane enter a specific phase, Shift (stance = null)
## swaps to the other one. See CombatState.change_stance for the Lunar Charge
## and Eclipse rules.

## The phase to enter. Null = Shift.
@export var stance: StatusEffectData


func execute(ctx: EffectContext) -> void:
	if ctx.source == ctx.combat.player:
		ctx.combat.change_stance(stance)


func describe(_upgraded: bool) -> String:
	return "ChangeStance(%s)" % (stance.id if stance else &"shift")
