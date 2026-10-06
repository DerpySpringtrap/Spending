class_name EffectContext
extends RefCounted
## Everything a GameEffect needs to resolve: who is acting, on whom, from which
## card, and any amount overrides.

var combat: CombatState
var source: Combatant
## Target picked when playing a card. Enemy moves set it to the player.
var chosen_target: Combatant
var card: CardInstance
var upgraded: bool = false
## Energy spent on an X card, or resource spent by a Vent clause.
var x_value: int = 0
## When >= 0, replaces every effect's amount (status triggers: stack count).
var amount_override: int = -1
## Flat bonus added to amounts (enemy ascension move bonuses).
var bonus: int = 0
## Multiplier for attack damage (enemy ascension scaling).
var damage_multiplier: float = 1.0
## Event data for reactive triggers ("attacker", "info", "card"...).
var payload: Dictionary = {}


func _init(p_combat: CombatState, p_source: Combatant, p_target: Combatant = null) -> void:
	combat = p_combat
	source = p_source
	chosen_target = p_target


func duplicate_context() -> EffectContext:
	var copy := EffectContext.new(combat, source, chosen_target)
	copy.card = card
	copy.upgraded = upgraded
	copy.x_value = x_value
	copy.amount_override = amount_override
	copy.bonus = bonus
	copy.damage_multiplier = damage_multiplier
	copy.payload = payload
	return copy


## Final (pre-modifier) amount for an effect: override or base+upgrade+bonus,
## then scaled.
func amount_for(effect: GameEffect) -> int:
	var base := amount_override if amount_override >= 0 else effect.get_amount(upgraded) + bonus
	match effect.scale:
		GameEffect.Scale.X:
			return base * x_value
		GameEffect.Scale.CLASS_RESOURCE:
			return base * combat.player.resource_value
		GameEffect.Scale.EXHAUST_PILE:
			return base * combat.exhaust_pile.size()
		GameEffect.Scale.HAND_SIZE:
			return base * combat.hand.size()
		GameEffect.Scale.LIVING_ALLIES:
			return base * maxi(combat.living_allies_of(source).size() - 1, 0)
	return base


func resolve_targets(effect: GameEffect) -> Array[Combatant]:
	var out: Array[Combatant] = []
	match effect.target:
		GameEffect.Target.CHOSEN:
			var t := chosen_target if chosen_target != null else source
			if t != null and not t.is_dead:
				out.append(t)
		GameEffect.Target.SELF:
			if source != null and not source.is_dead:
				out.append(source)
		GameEffect.Target.ALL_ENEMIES:
			out.assign(combat.living_opponents_of(source))
		GameEffect.Target.RANDOM_ENEMY:
			var options := combat.living_opponents_of(source)
			if not options.is_empty():
				out.append(combat.rng.pick(options, &"combat"))
		GameEffect.Target.ALL_ALLIES:
			out.assign(combat.living_allies_of(source))
		GameEffect.Target.ATTACKER:
			var attacker: Combatant = payload.get("attacker")
			if attacker != null and not attacker.is_dead:
				out.append(attacker)
		GameEffect.Target.EVERYONE:
			out.assign(combat.living_allies_of(source))
			out.append_array(combat.living_opponents_of(source))
	return out
