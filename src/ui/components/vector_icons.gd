class_name VectorIcons
extends RefCounted
## Flat vector glyphs drawn in code (placeholder art for intents, statuses,
## card art and HUD icons). Every glyph is authored in a -1..1 unit box and
## drawn with draw_set_transform, so it stays crisp at any size.
##
## Swap for real icons later by giving the data an icon texture; components
## only fall back to these glyphs when no texture is set.

## Placeholder glyph per status id (unknown ids get a lettered disc).
const STATUS_GLYPHS := {
	&"strength": &"sword",
	&"dexterity": &"shield",
	&"weak": &"broken_sword",
	&"vulnerable": &"target",
	&"frail": &"cracked_shield",
	&"poison": &"drop",
	&"burn": &"flame",
	&"thorns": &"spikes",
	&"stun": &"stun",
	&"searing_aegis": &"shield_flame",
	&"eternal_pyre": &"sun",
	&"ember_shell": &"shield",
	&"toxic_burst": &"burst",
	&"waxing": &"crescent",
	&"waning": &"crescent_wane",
	&"eclipse": &"eclipse",
	&"silver_reflection": &"shield",
	&"orbit": &"crescent",
	&"tidal_rhythm": &"shield",
	&"starfall": &"star",
	&"full_moon": &"sun",
	&"moonlit_vigil": &"crescent_wane",
	&"reassemble": &"skull",
	&"pack_tactics": &"burst",
	&"gilded_plate": &"shield",
	&"en_garde": &"spikes",
	&"soul_link": &"sparkle",
	&"incense": &"drop",
	&"golden_tithe": &"coin",
	&"errata": &"burst",
	&"cross_reference": &"shield",
	&"living_manuscript": &"cards",
	&"cursed_lexicon": &"skull",
	&"overclock": &"arrow_up",
	&"lock_on": &"target",
	&"constellation": &"star",
	&"airborne": &"arrow_up",
	&"drained": &"drop",
	&"halo": &"sun",
	&"fragment_bond": &"sparkle",
	&"clockwork_tick": &"hourglass",
	&"gravity": &"arrow_down",
	&"supernova": &"burst",
	&"taunt": &"shield",
	&"mycelial_network": &"drop",
	&"world_tree": &"arrow_up",
	&"symbiosis": &"sparkle",
	&"sap_well": &"drop",
	&"overgrowth": &"sparkle",
}

const INTENT_GLYPHS := {
	EnemyMoveData.Intent.ATTACK: &"sword",
	EnemyMoveData.Intent.ATTACK_DEFEND: &"sword",
	EnemyMoveData.Intent.ATTACK_BUFF: &"sword",
	EnemyMoveData.Intent.ATTACK_DEBUFF: &"sword",
	EnemyMoveData.Intent.DEFEND: &"shield",
	EnemyMoveData.Intent.DEFEND_BUFF: &"shield",
	EnemyMoveData.Intent.BUFF: &"arrow_up",
	EnemyMoveData.Intent.DEBUFF: &"drop",
	EnemyMoveData.Intent.STRONG_DEBUFF: &"skull",
	EnemyMoveData.Intent.SUMMON: &"sparkle",
	EnemyMoveData.Intent.CHARGING: &"hourglass",
	EnemyMoveData.Intent.ESCAPE: &"arrow_right",
	EnemyMoveData.Intent.STUNNED: &"stun",
	EnemyMoveData.Intent.SPECIAL: &"star",
	EnemyMoveData.Intent.UNKNOWN: &"question",
}

## Small secondary badge for combined intents.
const INTENT_SECONDARY := {
	EnemyMoveData.Intent.ATTACK_DEFEND: &"shield",
	EnemyMoveData.Intent.ATTACK_BUFF: &"arrow_up",
	EnemyMoveData.Intent.ATTACK_DEBUFF: &"drop",
	EnemyMoveData.Intent.DEFEND_BUFF: &"arrow_up",
}

const INTENT_COLORS := {
	&"sword": Color("#FF6A55"),
	&"shield": Color("#6CB8F0"),
	&"arrow_up": Color("#F0884A"),
	&"drop": Color("#B07CE0"),
	&"skull": Color("#C25AD6"),
	&"sparkle": Color("#7BE0C8"),
	&"hourglass": Color("#F6D743"),
	&"arrow_right": Color("#C8C8C8"),
	&"stun": Color("#F0E060"),
	&"star": Color("#F6B43C"),
	&"question": Color("#C8C8C8"),
}

## Card art: the type glyph, plus a small badge for the first known synergy tag.
const TAG_GLYPHS := {&"burn": &"flame", &"heat": &"sun", &"poison": &"drop", &"summon": &"sparkle"}
const TYPE_GLYPHS := {
	CardData.CardType.ATTACK: &"sword",
	CardData.CardType.SKILL: &"shield",
	CardData.CardType.POWER: &"star",
	CardData.CardType.STATUS: &"cracked_shield",
	CardData.CardType.CURSE: &"skull",
}


## Draws [param glyph] centred at [param center] fitting a [param size] box.
static func draw(ci: CanvasItem, glyph: StringName, center: Vector2, size: float, color: Color,
		outline: Color = Color(0, 0, 0, 0.55)) -> void:
	var s := size * 0.5
	if outline.a > 0.0:
		# Cheap outline: the glyph drawn slightly larger in a dark colour first.
		ci.draw_set_transform(center + Vector2(0, s * 0.06), 0.0, Vector2(s * 1.1, s * 1.1))
		_draw_unit(ci, glyph, outline, outline)
	ci.draw_set_transform(center, 0.0, Vector2(s, s))
	_draw_unit(ci, glyph, color, color.darkened(0.35))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _draw_unit(ci: CanvasItem, glyph: StringName, c: Color, shade: Color) -> void:
	match glyph:
		&"sword":
			_poly(ci, _rotated([Vector2(0, -1), Vector2(0.14, -0.78), Vector2(0.14, 0.32), Vector2(-0.14, 0.32), Vector2(-0.14, -0.78)], 0.785), c)
			_poly(ci, _rotated(_rect(-0.42, 0.3, 0.84, 0.16), 0.785), shade)
			_poly(ci, _rotated(_rect(-0.08, 0.46, 0.16, 0.38), 0.785), shade)
			ci.draw_circle(Vector2(0, 0.94).rotated(0.785), 0.12, c)
		&"broken_sword":
			_poly(ci, _rotated([Vector2(0.14, -0.2), Vector2(0.14, 0.32), Vector2(-0.14, 0.32), Vector2(-0.14, -0.1)], 0.785), c)
			_poly(ci, _rotated([Vector2(0, -1), Vector2(0.14, -0.78), Vector2(0.14, -0.42), Vector2(-0.14, -0.3), Vector2(-0.14, -0.78)], 0.785), Color(c, 0.55))
			_poly(ci, _rotated(_rect(-0.42, 0.3, 0.84, 0.16), 0.785), shade)
			_poly(ci, _rotated(_rect(-0.08, 0.46, 0.16, 0.38), 0.785), shade)
		&"shield", &"cracked_shield", &"shield_flame":
			var pts := PackedVector2Array([Vector2(-0.8, -0.85), Vector2(0.8, -0.85), Vector2(0.8, -0.05),
				Vector2(0.62, 0.42), Vector2(0.3, 0.75), Vector2(0, 0.95), Vector2(-0.3, 0.75), Vector2(-0.62, 0.42), Vector2(-0.8, -0.05)])
			_poly(ci, pts, c)
			_poly(ci, PackedVector2Array([Vector2(0, -0.85), Vector2(0.8, -0.85), Vector2(0.8, -0.05), Vector2(0.62, 0.42),
				Vector2(0.3, 0.75), Vector2(0, 0.95)]), shade)
			if glyph == &"cracked_shield":
				ci.draw_polyline(PackedVector2Array([Vector2(-0.1, -0.85), Vector2(0.12, -0.35), Vector2(-0.15, 0.05), Vector2(0.1, 0.5)]), Color(0, 0, 0, 0.8), 0.14)
			elif glyph == &"shield_flame":
				_poly(ci, _scaled(_flame_points(), 0.5, Vector2(0, 0.05)), Color("#FFD27A"))
		&"crescent", &"crescent_wane":
			var outer := PackedVector2Array()
			var flip := -1.0 if glyph == &"crescent_wane" else 1.0
			for i in 25:
				var a := -PI / 2 + PI * i / 24.0
				outer.append(Vector2(cos(a) * 0.9 * flip, sin(a) * 0.9))
			for i in 25:
				var a := PI / 2 - PI * i / 24.0
				outer.append(Vector2(cos(a) * 0.38 * flip, sin(a) * 0.9))
			_poly(ci, outer, c)
		&"crown":
			_poly(ci, PackedVector2Array([Vector2(-0.9, 0.6), Vector2(-0.9, -0.5), Vector2(-0.45, 0.0), Vector2(0, -0.8),
				Vector2(0.45, 0.0), Vector2(0.9, -0.5), Vector2(0.9, 0.6)]), c)
			_poly(ci, _rect(-0.9, 0.45, 1.8, 0.3), shade)
			for x in [-0.9, 0.0, 0.9]:
				ci.draw_circle(Vector2(x, -0.62 if x != 0.0 else -0.9), 0.13, c.lightened(0.3))
		&"eclipse":
			ci.draw_circle(Vector2.ZERO, 0.95, c)
			ci.draw_circle(Vector2(0.18, -0.08), 0.74, Color("#141A33"))
		&"star":
			_poly(ci, _star(5, 1.0, 0.45), c)
		&"sparkle":
			_poly(ci, _star(4, 1.0, 0.28), c)
		&"sun":
			_poly(ci, _star(10, 1.0, 0.7), shade)
			ci.draw_circle(Vector2.ZERO, 0.58, c)
		&"burst":
			_poly(ci, _star(8, 1.0, 0.55), c)
			ci.draw_circle(Vector2.ZERO, 0.32, shade)
		&"arrow_up":
			_poly(ci, PackedVector2Array([Vector2(0, -1), Vector2(0.85, 0), Vector2(0.3, 0), Vector2(0.3, 0.95), Vector2(-0.3, 0.95), Vector2(-0.3, 0), Vector2(-0.85, 0)]), c)
		&"arrow_down":
			_poly(ci, PackedVector2Array([Vector2(0, 1), Vector2(0.85, 0), Vector2(0.3, 0), Vector2(0.3, -0.95), Vector2(-0.3, -0.95), Vector2(-0.3, 0), Vector2(-0.85, 0)]), c)
		&"arrow_right":
			_poly(ci, PackedVector2Array([Vector2(1, 0), Vector2(0, -0.85), Vector2(0, -0.3), Vector2(-0.95, -0.3), Vector2(-0.95, 0.3), Vector2(0, 0.3), Vector2(0, 0.85)]), c)
		&"drop":
			ci.draw_circle(Vector2(0, 0.3), 0.62, c)
			_poly(ci, PackedVector2Array([Vector2(0, -1), Vector2(0.56, 0.05), Vector2(-0.56, 0.05)]), c)
			ci.draw_circle(Vector2(-0.22, 0.28), 0.16, Color(1, 1, 1, 0.45))
		&"flame":
			_poly(ci, _flame_points(), c)
			_poly(ci, _scaled(_flame_points(), 0.55, Vector2(0, 0.3)), Color("#FFD27A"))
		&"spikes":
			for i in 3:
				var x := -0.66 + i * 0.66
				_poly(ci, PackedVector2Array([Vector2(x, -0.95), Vector2(x + 0.33, 0.7), Vector2(x - 0.33, 0.7)]), c if i != 1 else shade)
			_poly(ci, _rect(-1, 0.62, 2, 0.3), shade)
		&"target":
			ci.draw_arc(Vector2.ZERO, 0.78, 0, TAU, 32, c, 0.2)
			ci.draw_arc(Vector2.ZERO, 0.38, 0, TAU, 24, c, 0.18)
			ci.draw_circle(Vector2.ZERO, 0.12, c)
		&"stun":
			for i in 3:
				var a := -2.4 + i * 0.8
				_poly(ci, _scaled(_star(5, 1.0, 0.45), 0.36, Vector2(cos(a), sin(a)) * 0.62 + Vector2(0, 0.35)), c)
		&"hourglass":
			_poly(ci, PackedVector2Array([Vector2(-0.7, -0.95), Vector2(0.7, -0.95), Vector2(0.08, 0), Vector2(-0.08, 0)]), c)
			_poly(ci, PackedVector2Array([Vector2(-0.08, 0), Vector2(0.08, 0), Vector2(0.7, 0.95), Vector2(-0.7, 0.95)]), shade)
		&"skull":
			ci.draw_circle(Vector2(0, -0.18), 0.74, c)
			_poly(ci, _rect(-0.42, 0.3, 0.84, 0.55), c)
			ci.draw_circle(Vector2(-0.28, -0.18), 0.2, Color(0, 0, 0, 0.85))
			ci.draw_circle(Vector2(0.28, -0.18), 0.2, Color(0, 0, 0, 0.85))
			_poly(ci, PackedVector2Array([Vector2(0, 0.08), Vector2(0.1, 0.26), Vector2(-0.1, 0.26)]), Color(0, 0, 0, 0.85))
		&"heart":
			ci.draw_circle(Vector2(-0.4, -0.3), 0.48, c)
			ci.draw_circle(Vector2(0.4, -0.3), 0.48, c)
			_poly(ci, PackedVector2Array([Vector2(-0.86, -0.12), Vector2(0.86, -0.12), Vector2(0, 0.95)]), c)
		&"coin":
			ci.draw_circle(Vector2.ZERO, 0.9, shade)
			ci.draw_circle(Vector2.ZERO, 0.72, c)
			_poly(ci, _rect(-0.1, -0.45, 0.2, 0.9), shade)
		&"chest":
			_poly(ci, _rect(-0.9, -0.15, 1.8, 1.0), shade)
			_poly(ci, PackedVector2Array([Vector2(-0.9, -0.15), Vector2(-0.75, -0.75), Vector2(0.75, -0.75), Vector2(0.9, -0.15)]), c)
			_poly(ci, _rect(-0.9, -0.22, 1.8, 0.16), Color(0, 0, 0, 0.5))
			_poly(ci, _rect(-0.14, -0.3, 0.28, 0.4), Color("#F6D743"))
		&"campfire":
			_poly(ci, _rotated(_rect(-0.9, 0.62, 1.8, 0.22), 0.25), Color("#6B4A33"))
			_poly(ci, _rotated(_rect(-0.9, 0.62, 1.8, 0.22), -0.25), Color("#7A5A40"))
			_poly(ci, _scaled(_flame_points(), 0.78, Vector2(0, -0.12)), c)
			_poly(ci, _scaled(_flame_points(), 0.42, Vector2(0, 0.12)), Color("#FFD27A"))
		&"horns":
			_poly(ci, PackedVector2Array([Vector2(-0.55, -0.1), Vector2(-1.0, -0.95), Vector2(-0.25, -0.35)]), shade)
			_poly(ci, PackedVector2Array([Vector2(0.55, -0.1), Vector2(1.0, -0.95), Vector2(0.25, -0.35)]), shade)
			ci.draw_circle(Vector2(0, 0.15), 0.62, c)
			ci.draw_circle(Vector2(-0.24, 0.05), 0.14, Color(0, 0, 0, 0.85))
			ci.draw_circle(Vector2(0.24, 0.05), 0.14, Color(0, 0, 0, 0.85))
			_poly(ci, _rect(-0.25, 0.42, 0.5, 0.12), Color(0, 0, 0, 0.6))
		&"cards":
			_poly(ci, _rotated(_rect(-0.55, -0.8, 1.1, 1.5), -0.25), shade)
			_poly(ci, _rotated(_rect(-0.5, -0.75, 1.1, 1.5), 0.12), c)
		&"lock":
			ci.draw_arc(Vector2(0, -0.25), 0.42, PI, TAU, 16, c, 0.18)
			_poly(ci, _rect(-0.62, -0.2, 1.24, 1.0), c)
			ci.draw_circle(Vector2(0, 0.22), 0.14, Color(0, 0, 0, 0.8))
		&"question":
			ci.draw_arc(Vector2(0, -0.3), 0.45, PI * 1.05, PI * 2.4, 16, c, 0.26)
			_poly(ci, _rect(-0.13, 0.05, 0.26, 0.35), c)
			ci.draw_circle(Vector2(0, 0.72), 0.16, c)
		_:
			ci.draw_circle(Vector2.ZERO, 0.85, c)


static func _poly(ci: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	ci.draw_colored_polygon(points, color)


static func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


static func _rotated(points: Array, angle: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append((p as Vector2).rotated(angle))
	return out


static func _scaled(points: PackedVector2Array, factor: float, offset: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p * factor + offset)
	return out


static func _star(points: int, outer: float, inner: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points * 2:
		var r := outer if i % 2 == 0 else inner
		var a := -PI / 2 + i * PI / points
		out.append(Vector2(cos(a), sin(a)) * r)
	return out


static func _flame_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -1), Vector2(0.3, -0.55), Vector2(0.62, -0.1), Vector2(0.72, 0.35), Vector2(0.5, 0.78),
		Vector2(0, 0.98), Vector2(-0.5, 0.78), Vector2(-0.72, 0.35), Vector2(-0.55, -0.05), Vector2(-0.25, 0.15),
		Vector2(-0.2, -0.4),
	])


static func card_glyph(card: CardData) -> StringName:
	return TYPE_GLYPHS.get(card.type, &"star")


## Secondary badge from the card's first known synergy tag, or &"".
static func card_tag_glyph(card: CardData) -> StringName:
	for tag in card.tags:
		if TAG_GLYPHS.has(tag):
			return TAG_GLYPHS[tag]
	return &""


static func status_glyph(status: StatusEffectData) -> StringName:
	return STATUS_GLYPHS.get(status.id, &"")
