class_name CardText
extends RefCounted
## Renders a card's description template with live numbers.
##
## "{dmg}" is replaced by the preview value of the effect whose value_key is
## &"dmg", computed through the same pipeline as real play (Strength, Weak, the
## hovered target's Vulnerable, Heat for "per Heat" cards...). With BBCode on,
## numbers that differ from the printed base are coloured up/down.

const COLOR_UP := "#7CFC8A"
const COLOR_DOWN := "#FF6B6B"

const KEYWORD_NAMES := {
	CardData.KW_EXHAUST: "Exhaust",
	CardData.KW_RETAIN: "Retain",
	CardData.KW_INNATE: "Innate",
	CardData.KW_ETHEREAL: "Ethereal",
}


## [param combat] null = out-of-combat text (deck view, rewards): base numbers.
static func render(card: CardInstance, combat: CombatState = null, target: Combatant = null, bbcode: bool = false) -> String:
	var text := card.data.get_description_template(card.upgraded)
	var ctx: EffectContext = null
	if combat != null:
		ctx = EffectContext.new(combat, combat.player, target)
		ctx.card = card
		ctx.upgraded = card.upgraded
		ctx.x_value = combat.player.energy
	var values := {}
	_collect(card.data.effects, ctx, card.upgraded, values)
	_collect(card.data.on_discard_effects, ctx, card.upgraded, values)
	for key in values:
		var shown: int = values[key][0]
		var base: int = values[key][1]
		var number := str(shown)
		if bbcode and shown != base:
			number = "[color=%s]%d[/color]" % [COLOR_UP if shown > base else COLOR_DOWN, shown]
		text = text.replace("{%s}" % key, number)
	var keyword_text: PackedStringArray = []
	for keyword in card.data.get_keywords(card.upgraded):
		keyword_text.append(KEYWORD_NAMES.get(keyword, String(keyword).capitalize()) + ".")
	if not keyword_text.is_empty():
		text += ("\n" if not text.is_empty() else "") + " ".join(keyword_text)
	return text


static func _collect(effects: Array[GameEffect], ctx: EffectContext, upgraded: bool, values: Dictionary) -> void:
	for effect in effects:
		if effect.value_key != &"" and not values.has(effect.value_key):
			var base := effect.get_amount(upgraded)
			var shown := base
			if ctx != null:
				shown = effect.preview_amount(ctx)
			values[effect.value_key] = [shown, base]
		var sub_ctx := ctx
		if ctx != null and effect is SpendClassResourceEffect:
			sub_ctx = effect.make_preview_context(ctx)
		_collect(effect.get_sub_effects(), sub_ctx, upgraded, values)


## Short, stable list of every {token} in a template (content validation).
static func find_tokens(template: String) -> PackedStringArray:
	var tokens: PackedStringArray = []
	var regex := RegEx.create_from_string("\\{([a-z_0-9]+)\\}")
	for m in regex.search_all(template):
		tokens.append(m.get_string(1))
	return tokens


## All value_keys a card defines (including nested bonus effects).
static func collect_keys(card: CardData) -> PackedStringArray:
	var keys: PackedStringArray = []
	_collect_keys(card.effects, keys)
	_collect_keys(card.on_discard_effects, keys)
	return keys


static func _collect_keys(effects: Array[GameEffect], keys: PackedStringArray) -> void:
	for effect in effects:
		if effect.value_key != &"":
			keys.append(String(effect.value_key))
		_collect_keys(effect.get_sub_effects(), keys)
