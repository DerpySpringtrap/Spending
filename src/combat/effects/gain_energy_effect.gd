@tool
class_name GainEnergyEffect
extends GameEffect
## "Gain X Energy".


func execute(ctx: EffectContext) -> void:
	ctx.combat.gain_energy(ctx.amount_for(self))
