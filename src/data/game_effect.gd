@tool
class_name GameEffect
extends Resource
## Base class for every atomic, data-driven effect in the game.
##
## Cards, potions, relics, status triggers and enemy moves are all built from
## lists of GameEffects ("deal 6 damage", "gain 5 block", "apply 2 Poison").
## A designer composes content in the inspector by stacking effect resources;
## new mechanics are added by writing one small GameEffect subclass rather than
## touching card scripts.
##
## Concrete subclasses live in res://src/combat/effects/ (Milestone 1).

## Who the effect hits, relative to the thing that owns it.
enum Target {
	CHOSEN,          ## The target picked when the card was played (falls back to SELF).
	SELF,            ## The owner (player for cards/relics, the enemy for its moves).
	ALL_ENEMIES,     ## All enemies of the owner.
	RANDOM_ENEMY,    ## One random living enemy of the owner (re-rolled per execution).
	ALL_ALLIES,      ## The owner's side, including summons.
	ATTACKER,        ## Only meaningful in reactive triggers (e.g. Thorns).
	EVERYONE,
	SUMMONS,         ## The owner side's living summons (Rootmother).
	EVENT_TARGET,    ## Reactive triggers: the combatant the event happened to (payload "target").
}

## Optional multiplier source: the final amount is amount × this value.
## Used for "Deal 4 damage per Heat", X-cost cards, "per card in Erased pile"...
enum Scale {
	NONE,
	X,               ## Energy spent on an X card, or resource spent by a Vent/Inscribe/Graft.
	CLASS_RESOURCE,  ## Current class resource value (without spending it).
	EXHAUST_PILE,    ## Cards in the exhaust (Erased) pile.
	HAND_SIZE,       ## Cards in hand.
	LIVING_ALLIES,   ## Other living combatants on the source's side.
	STANCE_CHANGES,  ## Phase changes the player made this turn (Moonblade).
}

## Base magnitude (damage, block, stacks, cards drawn...).
@export var amount: int = 0
## Added to [member amount] when the owning card is upgraded.
@export var upgrade_delta: int = 0
## Number of repetitions (multi-hit attacks: "Deal 3 damage 4 times").
@export_range(1, 20) var times: int = 1
@export var target: Target = Target.CHOSEN
## Token used in description templates. A card description of
## "Deal {dmg} damage." looks up the effect whose value_key is &"dmg" and shows
## its live, stat-modified preview value.
@export var value_key: StringName = &""
@export var scale: Scale = Scale.NONE


func get_amount(upgraded: bool) -> int:
	return amount + (upgrade_delta if upgraded else 0)


## Applies the effect. [param ctx] carries the combat state, source, chosen
## target, owning card and any amount override (status triggers pass their
## stack count through it). Use [method EffectContext.amount_for] to read the
## final amount so upgrades, scaling and overrides are respected.
func execute(_ctx: EffectContext) -> void:
	push_error("%s does not implement execute()" % get_script().resource_path)


## Value shown on the card face / intent icon after modifiers (Strength, Weak,
## Vulnerable on the hovered target...). Defaults to the scaled amount.
func preview_amount(ctx: EffectContext) -> int:
	return ctx.amount_for(self)


## Nested effects (e.g. the bonus of a Vent clause), so card text and tooling
## can find their value_keys.
func get_sub_effects() -> Array[GameEffect]:
	return []


## Short human-readable summary used by tooling and debug overlays.
func describe(upgraded: bool) -> String:
	return "%s(%d)" % [get_script().get_global_name(), get_amount(upgraded)]
