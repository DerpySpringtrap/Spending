class_name CardTooltips
extends RefCounted
## Builds the keyword/status glossary shown beside a hovered card.

const GLOSSARY := {
	"Block": "Prevents damage until the start of your next turn.",
	"Stoke": "Gain Heat.",
	"Vent": "If you have enough Heat, spend it to get the bonus. Otherwise the card plays without it.",
	"Overheat": "End your turn at max Heat: deal 15 damage to ALL enemies, lose 2 HP, reset Heat.",
	"Wax": "Enter the Waxing phase. Changing phase grants 1 Lunar Charge.",
	"Wane": "Enter the Waning phase. Changing phase grants 1 Lunar Charge.",
	"Shift": "Change to the other phase (Waxing if you have none). Changing phase grants 1 Lunar Charge.",
	"Lunar Charge": "Gained when you change phase. Change phase at 4 to enter Eclipse.",
	"Riposte": "In Waning, deal 2 damage back whenever an enemy attacks you.",
	"Ink": "The Hollow Scribe's resource (up to 10, kept between turns). Gain 1 whenever you discard a card from an effect or Erase a card.",
	"Inscribe": "If you have enough Ink, spend it to get the bonus. Otherwise the card plays without it.",
	"Footnote": "Happens when this card is discarded by an effect (not at the end of your turn).",
	"Erase": "Exhaust: removed from play until the end of combat. Erasing a card gains 1 Ink.",
	"Eclipse": "Both phases at once, stronger (+3 damage per hit, +3 Block, Riposte 3), plus draw 2. Ends at the end of your turn and resets Lunar Charge.",
}

const KEYWORDS := {
	CardData.KW_EXHAUST: ["Exhaust", "Removed from play until the end of combat."],
	CardData.KW_RETAIN: ["Retain", "Not discarded at the end of your turn."],
	CardData.KW_INNATE: ["Innate", "Always in your opening hand."],
	CardData.KW_ETHEREAL: ["Ethereal", "Exhausted if still in your hand at the end of your turn."],
}


## BBCode: one section per keyword, mechanic and status mentioned by the card.
static func for_card(card: CardInstance) -> String:
	var sections: PackedStringArray = []
	var text := card.data.get_description_template(card.upgraded)
	for keyword in card.data.get_keywords(card.upgraded):
		if KEYWORDS.has(keyword):
			sections.append(_section(CardText.keyword_name(keyword, card.data), KEYWORDS[keyword][1]))
	if card.data.cost == CardData.COST_UNPLAYABLE:
		sections.append(_section("Unplayable", "This card can't be played."))
	for term in GLOSSARY:
		if RegEx.create_from_string("\\b%s\\b" % term).search(text) != null:
			sections.append(_section(term, GLOSSARY[term]))
	for status: StatusEffectData in ContentDB.statuses.values():
		if status.hidden or status.display_name == card.data.display_name:
			continue
		if text.contains(status.display_name):
			sections.append(_section(status.display_name, status.description.replace("{stacks}", "X")))
	return "\n\n".join(sections)


static func _section(title: String, body: String) -> String:
	return "[color=#%s][b]%s[/b][/color]\n%s" % [UIStyle.GOLD.to_html(false), title, body]
