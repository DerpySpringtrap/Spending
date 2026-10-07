class_name PlaceholderArt
extends RefCounted
## Flat vector stand-in bodies built from Polygon2Ds, until real art exists.
## Origin = feet; bodies extend upward (negative y). Enemies face left.
## Replace by assigning EnemyData.visual_scene / CharacterClassData.combat_scene.

## Builds the body for [param id]. Sets meta "height" and "width" on the root.
static func build(id: StringName, accent: Color = Color("#E8692C")) -> Node2D:
	var root := Node2D.new()
	match id:
		&"pyre_warden":
			_warden(root, accent)
		&"moonblade":
			_moonblade(root, accent)
		&"hollow_scribe":
			_scribe(root)
		&"mire_toad":
			_toad(root)
		&"bog_lurker":
			_lurker(root)
		&"thornback_beetle":
			_beetle(root)
		&"drowned_matriarch":
			_matriarch(root)
		&"broodling":
			_broodling(root)
		&"wisp_lantern":
			_wisp(root)
		&"hollow_woodsman":
			_woodsman(root)
		&"gorehorn_bull":
			_bull(root)
		&"swamp_witch":
			_witch(root)
		&"toad_familiar":
			_familiar(root)
		&"gilded_skeleton":
			_skeleton(root)
		&"candle_acolyte":
			_acolyte(root)
		&"coin_mimic":
			_mimic(root)
		&"crypt_hound":
			_hound(root)
		&"embalmer":
			_embalmer(root)
		&"gilded_knight":
			_knight(root)
		&"reliquary_dawn":
			_reliquary(root, Color("#F2C46B"))
		&"reliquary_dusk":
			_reliquary(root, Color("#9A86D8"))
		&"plague_censer":
			_censer(root)
		&"gilded_hierophant":
			_hierophant(root)
		&"gold_idol":
			_idol(root)
		&"clockwork_sentinel":
			_sentinel(root)
		&"star_shard":
			_shard(root)
		&"storm_harpy":
			_harpy(root)
		&"void_leech":
			_leech(root)
		&"astral_weaver":
			_weaver(root)
		&"chronomancer_construct":
			_chronomancer(root)
		&"starfall_seraph":
			_seraph(root)
		&"halo_fragment":
			_halo_fragment(root)
		&"the_orrery":
			_orrery(root)
		_:
			_blob(root, id)
	return root


static func _poly(root: Node2D, points: PackedVector2Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	p.antialiased = true
	p.use_parent_material = true
	root.add_child(p)
	return p


static func ellipse(c: Vector2, rx: float, ry: float, n: int = 28, from: float = 0.0, to: float = TAU) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + (1 if to - from < TAU else 0):
		var a := from + (to - from) * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func rounded_rect(x: float, y: float, w: float, h: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [Vector2(x + w - r, y + r), Vector2(x + w - r, y + h - r), Vector2(x + r, y + h - r), Vector2(x + r, y + r)]
	for i in 4:
		for k in 5:
			var a := -PI / 2 + i * PI / 2 + k * (PI / 2) / 4
			pts.append(corners[i] + Vector2(cos(a), sin(a)) * r)
	return pts


static func _meta(root: Node2D, width: float, height: float) -> void:
	root.set_meta("width", width)
	root.set_meta("height", height)


static func _warden(root: Node2D, accent: Color) -> void:
	var iron := Color("#4A403A")
	var dark := Color("#2E2724")
	var gold := Color("#F6B43C")
	# Mace (behind)
	_poly(root, PackedVector2Array([Vector2(-72, -112), Vector2(-62, -116), Vector2(-92, -212), Vector2(-102, -208)]), Color("#6B4A33"))
	_poly(root, VectorIcons._scaled(VectorIcons._star(8, 1.0, 0.7), 26, Vector2(-100, -222)), iron.darkened(0.2))
	_poly(root, ellipse(Vector2(-100, -222), 17, 17), iron.lightened(0.1))
	# Legs
	_poly(root, rounded_rect(-44, -74, 30, 74, 8), dark)
	_poly(root, rounded_rect(12, -74, 30, 74, 8), dark)
	# Torso with ember core
	_poly(root, PackedVector2Array([Vector2(-58, -64), Vector2(58, -64), Vector2(72, -168), Vector2(-72, -168)]), iron)
	_poly(root, PackedVector2Array([Vector2(-26, -96), Vector2(26, -96), Vector2(18, -146), Vector2(-18, -146)]), accent)
	_poly(root, ellipse(Vector2(0, -122), 10, 14), gold)
	_poly(root, rounded_rect(-60, -76, 120, 14, 4), gold.darkened(0.25))
	# Shoulders
	_poly(root, ellipse(Vector2(-70, -166), 34, 22), iron.lightened(0.12))
	_poly(root, ellipse(Vector2(70, -166), 34, 22), iron.lightened(0.12))
	# Helm, visor glow and chimney plume
	_poly(root, rounded_rect(-34, -240, 68, 72, 14), iron.lightened(0.06))
	_poly(root, rounded_rect(-24, -212, 48, 9, 4), gold)
	_poly(root, rounded_rect(-8, -266, 16, 30, 4), dark)
	_poly(root, ellipse(Vector2(0, -272), 11, 11), accent)
	_poly(root, ellipse(Vector2(0, -274), 6, 6), gold)
	# Tower shield (front, facing right)
	_poly(root, rounded_rect(30, -186, 76, 158, 14), Color("#5A4A40"))
	_poly(root, rounded_rect(38, -178, 60, 142, 10), Color("#6B584C"))
	_poly(root, VectorIcons._scaled(VectorIcons._flame_points(), 24, Vector2(68, -108)), accent)
	_poly(root, VectorIcons._scaled(VectorIcons._flame_points(), 12, Vector2(68, -100)), gold)
	_meta(root, 210, 280)


static func _moonblade(root: Node2D, accent: Color) -> void:
	var navy := Color("#1E2547")
	var dark := Color("#141A33")
	var silver := Color("#C9D2E3")
	var gold := Color("#E9D8A6")
	var violet := Color("#7A5CC7")
	# Crescent halo (behind the head)
	var halo := ellipse(Vector2(0, -232), 46, 46, 32, -PI * 0.15, PI * 1.15)
	var inner := ellipse(Vector2(10, -238), 38, 38, 32, PI * 1.15, -PI * 0.15)
	halo.append_array(inner)
	_poly(root, halo, Color(gold, 0.85))
	# Long cape flowing to the left
	_poly(root, PackedVector2Array([Vector2(-30, -176), Vector2(26, -176), Vector2(30, -40), Vector2(-20, -8), Vector2(-96, -4),
		Vector2(-70, -60)]), violet.darkened(0.35))
	# Legs (slim, fencer's stance)
	_poly(root, PackedVector2Array([Vector2(-28, -80), Vector2(-12, -80), Vector2(-30, 0), Vector2(-48, 0)]), dark)
	_poly(root, PackedVector2Array([Vector2(6, -80), Vector2(22, -80), Vector2(44, 0), Vector2(26, 0)]), dark)
	# Torso: slender doublet with a silver sash
	_poly(root, PackedVector2Array([Vector2(-30, -78), Vector2(30, -78), Vector2(36, -170), Vector2(-36, -170)]), navy)
	_poly(root, PackedVector2Array([Vector2(-34, -160), Vector2(-24, -168), Vector2(32, -90), Vector2(22, -84)]), silver)
	_poly(root, ellipse(Vector2(0, -124), 7, 7), accent.lightened(0.3))
	# Sword arm reaching forward (right) with a rapier
	_poly(root, PackedVector2Array([Vector2(24, -160), Vector2(36, -166), Vector2(78, -128), Vector2(70, -118)]), navy.lightened(0.1))
	_poly(root, ellipse(Vector2(76, -122), 9, 9), Color("#D9C6B0"))
	_poly(root, PackedVector2Array([Vector2(80, -126), Vector2(84, -122), Vector2(176, -176), Vector2(174, -180)]), silver.lightened(0.2))
	_poly(root, ellipse(Vector2(80, -124), 12, 5, 16), gold)
	# Head with a hood-like cowl
	_poly(root, ellipse(Vector2(0, -196), 22, 26), Color("#D9C6B0"))
	_poly(root, PackedVector2Array([Vector2(-26, -186), Vector2(-24, -218), Vector2(0, -232), Vector2(24, -218), Vector2(26, -186),
		Vector2(16, -204), Vector2(-16, -204)]), dark)
	_poly(root, rounded_rect(4, -200, 12, 4, 2), violet.lightened(0.4))
	_meta(root, 200, 280)


static func _toad(root: Node2D) -> void:
	var skin := Color("#6F8A3A")
	_poly(root, ellipse(Vector2(-58, -6), 22, 9), skin.darkened(0.3))
	_poly(root, ellipse(Vector2(54, -6), 22, 9), skin.darkened(0.3))
	_poly(root, ellipse(Vector2(0, -52), 82, 50), skin)
	_poly(root, ellipse(Vector2(-6, -36), 56, 30), Color("#A8B96A"))
	for spot in [Vector2(40, -78), Vector2(58, -50), Vector2(20, -92)]:
		_poly(root, ellipse(spot, 9, 6), skin.darkened(0.25))
	for eye in [Vector2(-38, -96), Vector2(16, -100)]:
		_poly(root, ellipse(eye, 21, 20), skin.darkened(0.1))
		_poly(root, ellipse(eye + Vector2(0, -2), 15, 14), Color("#E8E0A0"))
		_poly(root, ellipse(eye + Vector2(-5, -1), 6, 9), Color("#141010"))
	_poly(root, PackedVector2Array([Vector2(-78, -54), Vector2(-20, -44), Vector2(30, -50), Vector2(30, -46), Vector2(-20, -40), Vector2(-78, -50)]), Color("#2E3A18"))
	_meta(root, 170, 125)


static func _lurker(root: Node2D) -> void:
	var hide_color := Color("#3F4A35")
	var spike := Color("#7E8F5A")
	for i in 5:
		var x := -30 + i * 24
		var y := -176 + absf(i - 1.5) * 16
		_poly(root, PackedVector2Array([Vector2(x - 12, y + 14), Vector2(x, y - 26), Vector2(x + 12, y + 14)]), spike)
	_poly(root, PackedVector2Array([Vector2(-70, 0), Vector2(-82, -60), Vector2(-62, -138), Vector2(-12, -184), Vector2(50, -168),
		Vector2(82, -110), Vector2(78, 0)]), hide_color)
	_poly(root, PackedVector2Array([Vector2(-42, -122), Vector2(-24, -110), Vector2(-80, -8), Vector2(-100, -4), Vector2(-106, -16)]), hide_color.darkened(0.15))
	for c in [Vector2(-104, -6), Vector2(-92, 0), Vector2(-112, -14)]:
		_poly(root, PackedVector2Array([c, c + Vector2(-10, 8), c + Vector2(-4, -6)]), Color("#C9C2A0"))
	_poly(root, ellipse(Vector2(-58, -142), 40, 31), hide_color.darkened(0.2))
	_poly(root, ellipse(Vector2(-78, -146), 8, 5), Color("#F6D743"))
	_poly(root, ellipse(Vector2(-56, -152), 8, 5), Color("#F6D743"))
	_poly(root, PackedVector2Array([Vector2(-92, -126), Vector2(-60, -122), Vector2(-66, -116), Vector2(-90, -120)]), Color("#1E241A"))
	for drip in [Vector2(10, -150), Vector2(40, -120), Vector2(-20, -90)]:
		_poly(root, ellipse(drip, 7, 12), Color("#6E8A4A"))
	_meta(root, 190, 200)


static func _beetle(root: Node2D) -> void:
	var leg := Color("#1C262C")
	for i in 3:
		var x := -40 + i * 40
		_poly(root, PackedVector2Array([Vector2(x - 4, -32), Vector2(x + 4, -32), Vector2(x - 6, 0), Vector2(x - 16, 0)]), leg)
	var shell := Color("#2F5560")
	_poly(root, ellipse(Vector2(10, -30), 88, 74, 24, PI, TAU), shell)
	_poly(root, ellipse(Vector2(10, -30), 88, 10, 16, 0, PI), shell.darkened(0.3))
	_poly(root, ellipse(Vector2(-6, -62), 40, 22, 16, PI, TAU), shell.lightened(0.18))
	var thorn := Color("#B5A06A")
	for i in 5:
		var a := PI + PI * (i + 0.8) / 6.6
		var base := Vector2(10, -30) + Vector2(cos(a) * 82, sin(a) * 68)
		var tip := Vector2(10, -30) + Vector2(cos(a) * 112, sin(a) * 96)
		var side := (tip - base).orthogonal().normalized() * 9
		_poly(root, PackedVector2Array([base - side, tip, base + side]), thorn)
	_poly(root, ellipse(Vector2(-86, -34), 30, 24), Color("#24323A"))
	_poly(root, ellipse(Vector2(-100, -42), 7, 7), Color("#FF5A4A"))
	_poly(root, PackedVector2Array([Vector2(-110, -26), Vector2(-132, -20), Vector2(-112, -16)]), thorn)
	_meta(root, 210, 140)


static func _blob(root: Node2D, id: StringName) -> void:
	var color := Color.from_hsv(float(hash(id) % 360) / 360.0, 0.45, 0.55)
	_poly(root, ellipse(Vector2(0, -70), 70, 70), color)
	_poly(root, ellipse(Vector2(-22, -84), 12, 14), Color.WHITE)
	_poly(root, ellipse(Vector2(-26, -84), 5, 7), Color.BLACK)
	_poly(root, ellipse(Vector2(18, -84), 12, 14), Color.WHITE)
	_poly(root, ellipse(Vector2(14, -84), 5, 7), Color.BLACK)
	_meta(root, 140, 140)


static func _matriarch(root: Node2D) -> void:
	var skin := Color("#4E6B3A")
	var belly := Color("#8FA66A")
	var water := Color("#2E5560")
	# Swamp pool she rises from
	_poly(root, ellipse(Vector2(0, -8), 170, 26), water)
	_poly(root, ellipse(Vector2(0, -12), 140, 16), water.lightened(0.15))
	# Huge body
	_poly(root, ellipse(Vector2(0, -120), 140, 118), skin)
	_poly(root, ellipse(Vector2(-10, -88), 96, 74), belly)
	for spot in [Vector2(80, -170), Vector2(110, -110), Vector2(60, -205), Vector2(-90, -180)]:
		_poly(root, ellipse(spot, 16, 11), skin.darkened(0.25))
	# Crown of reeds and bone
	for i in 5:
		var x := -60 + i * 30
		_poly(root, PackedVector2Array([Vector2(x - 10, -224), Vector2(x, -290 + absf(i - 2) * 14), Vector2(x + 10, -224)]), Color("#C9B98A"))
	_poly(root, rounded_rect(-72, -236, 144, 20, 8), Color("#8A6A45"))
	_poly(root, ellipse(Vector2(0, -226), 10, 10), Color("#7BE0C8"))
	# Eyes and maw
	for eye in [Vector2(-52, -186), Vector2(30, -190)]:
		_poly(root, ellipse(eye, 26, 24), skin.darkened(0.1))
		_poly(root, ellipse(eye + Vector2(0, -2), 19, 17), Color("#E8E0A0"))
		_poly(root, ellipse(eye + Vector2(-6, 0), 7, 13), Color("#141010"))
	_poly(root, PackedVector2Array([Vector2(-110, -120), Vector2(-20, -100), Vector2(70, -112), Vector2(70, -104), Vector2(-20, -90), Vector2(-110, -112)]), Color("#1E2A14"))
	# Dripping weeds
	for drip in [Vector2(-120, -60), Vector2(118, -70), Vector2(-60, -30)]:
		_poly(root, ellipse(drip, 8, 22), Color("#3F5A2E"))
	_meta(root, 300, 290)


static func _broodling(root: Node2D) -> void:
	var skin := Color("#5E7F3A")
	_poly(root, ellipse(Vector2(0, -30), 40, 28), skin)
	_poly(root, ellipse(Vector2(-4, -22), 26, 15), Color("#A8B96A"))
	for eye in [Vector2(-16, -54), Vector2(10, -56)]:
		_poly(root, ellipse(eye, 11, 10), skin.darkened(0.1))
		_poly(root, ellipse(eye, 7, 7), Color("#E8E0A0"))
		_poly(root, ellipse(eye + Vector2(-2, 0), 3, 5), Color("#141010"))
	_meta(root, 90, 70)


static func _wisp(root: Node2D) -> void:
	var glow := Color("#7BE0C8")
	_poly(root, ellipse(Vector2(0, -110), 60, 60), Color(glow, 0.12))
	_poly(root, ellipse(Vector2(0, -110), 40, 40), Color(glow, 0.25))
	_poly(root, rounded_rect(-24, -150, 48, 70, 12), Color("#3A3A30"))
	_poly(root, rounded_rect(-17, -140, 34, 50, 8), glow)
	_poly(root, VectorIcons._scaled(VectorIcons._flame_points(), 14, Vector2(0, -118)), Color("#E8FFF8"))
	_poly(root, rounded_rect(-10, -168, 20, 20, 6), Color("#3A3A30"))
	_meta(root, 110, 170)


static func _woodsman(root: Node2D) -> void:
	var bark := Color("#5B4030")
	var dark := Color("#2E221A")
	_poly(root, rounded_rect(-38, -70, 24, 70, 6), dark)
	_poly(root, rounded_rect(14, -70, 24, 70, 6), dark)
	_poly(root, PackedVector2Array([Vector2(-46, -64), Vector2(46, -64), Vector2(54, -170), Vector2(-54, -170)]), bark)
	_poly(root, ellipse(Vector2(0, -116), 18, 26), Color("#140E0A"))
	_poly(root, ellipse(Vector2(0, -204), 34, 38), bark.darkened(0.1))
	_poly(root, ellipse(Vector2(-12, -208), 6, 6), Color("#F6D743"))
	_poly(root, ellipse(Vector2(12, -208), 6, 6), Color("#F6D743"))
	# Axe
	_poly(root, PackedVector2Array([Vector2(-60, -150), Vector2(-52, -152), Vector2(-90, -40), Vector2(-98, -42)]), Color("#6B4A33"))
	_poly(root, PackedVector2Array([Vector2(-58, -160), Vector2(-104, -186), Vector2(-112, -140), Vector2(-66, -138)]), Color("#9AA0A6"))
	_meta(root, 170, 240)


static func _bull(root: Node2D) -> void:
	var hide := Color("#5A2E26")
	_poly(root, rounded_rect(-100, -60, 26, 60, 6), hide.darkened(0.3))
	_poly(root, rounded_rect(60, -60, 26, 60, 6), hide.darkened(0.3))
	_poly(root, ellipse(Vector2(10, -100), 110, 62), hide)
	_poly(root, ellipse(Vector2(40, -120), 70, 48), hide.lightened(0.08))
	_poly(root, ellipse(Vector2(-92, -118), 44, 40), hide.darkened(0.1))
	_poly(root, PackedVector2Array([Vector2(-112, -148), Vector2(-160, -196), Vector2(-104, -160)]), Color("#E9E2D8"))
	_poly(root, PackedVector2Array([Vector2(-80, -150), Vector2(-60, -206), Vector2(-70, -150)]), Color("#E9E2D8"))
	_poly(root, ellipse(Vector2(-108, -122), 7, 7), Color("#FF5A4A"))
	_poly(root, ellipse(Vector2(-118, -96), 14, 8), Color("#2A1410"))
	_meta(root, 260, 200)


static func _witch(root: Node2D) -> void:
	var robe := Color("#3E3A5A")
	_poly(root, PackedVector2Array([Vector2(-58, 0), Vector2(58, 0), Vector2(24, -150), Vector2(-24, -150)]), robe)
	_poly(root, ellipse(Vector2(0, -170), 28, 30), Color("#9FB88A"))
	_poly(root, PackedVector2Array([Vector2(-48, -186), Vector2(48, -186), Vector2(6, -276), Vector2(-4, -276)]), robe.darkened(0.25))
	_poly(root, rounded_rect(-56, -192, 112, 12, 5), robe.darkened(0.35))
	_poly(root, ellipse(Vector2(-10, -172), 5, 5), Color("#E0453A"))
	_poly(root, ellipse(Vector2(10, -172), 5, 5), Color("#E0453A"))
	_poly(root, PackedVector2Array([Vector2(-70, -110), Vector2(-62, -112), Vector2(-74, 0), Vector2(-82, 0)]), Color("#6B4A33"))
	_poly(root, ellipse(Vector2(-68, -120), 14, 14), Color("#B07CE0"))
	_meta(root, 150, 270)


static func _familiar(root: Node2D) -> void:
	_toad(root)
	root.scale = Vector2(0.7, 0.7)
	_meta(root, 120, 90)


# --- Act 2: The Gilded Catacombs ---------------------------------------------------

const BONE := Color("#D9CFB4")
const GOLD := Color("#E8B84A")


static func _skeleton(root: Node2D) -> void:
	var dark := Color("#2A241C")
	# Legs and pelvis
	_poly(root, rounded_rect(-26, -78, 12, 78, 5), BONE.darkened(0.1))
	_poly(root, rounded_rect(12, -78, 12, 78, 5), BONE.darkened(0.1))
	_poly(root, ellipse(Vector2(0, -84), 34, 14), BONE)
	# Spine and ribs
	_poly(root, rounded_rect(-6, -170, 12, 90, 5), BONE)
	for i in 4:
		var y := -160 + i * 18
		_poly(root, ellipse(Vector2(0, y), 36 - i * 3, 7), BONE.darkened(0.05 * i))
	_poly(root, rounded_rect(-44, -174, 88, 12, 5), GOLD)
	# Arms with a gilded sword (forward = left)
	_poly(root, PackedVector2Array([Vector2(-38, -168), Vector2(-30, -172), Vector2(-62, -118), Vector2(-70, -122)]), BONE)
	_poly(root, PackedVector2Array([Vector2(-70, -118), Vector2(-62, -122), Vector2(-150, -190), Vector2(-156, -184)]), GOLD.lightened(0.15))
	_poly(root, rounded_rect(-80, -128, 26, 8, 3), GOLD.darkened(0.2))
	_poly(root, PackedVector2Array([Vector2(36, -168), Vector2(44, -164), Vector2(52, -100), Vector2(44, -98)]), BONE)
	# Skull with a gold crown
	_poly(root, ellipse(Vector2(0, -200), 26, 28), BONE)
	_poly(root, rounded_rect(-14, -186, 28, 14, 4), BONE.darkened(0.1))
	_poly(root, ellipse(Vector2(-10, -202), 7, 8), dark)
	_poly(root, ellipse(Vector2(10, -202), 7, 8), dark)
	_poly(root, PackedVector2Array([Vector2(-24, -222), Vector2(-24, -240), Vector2(-12, -228), Vector2(0, -246), Vector2(12, -228),
		Vector2(24, -240), Vector2(24, -222)]), GOLD)
	_meta(root, 150, 250)


static func _acolyte(root: Node2D) -> void:
	var robe := Color("#5A3A2A")
	_poly(root, PackedVector2Array([Vector2(-50, 0), Vector2(50, 0), Vector2(26, -140), Vector2(-26, -140)]), robe)
	_poly(root, rounded_rect(-8, -140, 16, 140, 4), GOLD.darkened(0.3))
	# Hood with a dark face
	_poly(root, ellipse(Vector2(0, -160), 30, 34), robe.darkened(0.2))
	_poly(root, ellipse(Vector2(-4, -156), 18, 22), Color("#140E0A"))
	_poly(root, ellipse(Vector2(-10, -160), 3, 3), Color("#FFD27A"))
	_poly(root, ellipse(Vector2(2, -160), 3, 3), Color("#FFD27A"))
	# Candle held forward with a glow
	_poly(root, PackedVector2Array([Vector2(-20, -112), Vector2(-12, -118), Vector2(-56, -96), Vector2(-60, -88)]), robe.lightened(0.1))
	_poly(root, rounded_rect(-70, -130, 12, 36, 3), Color("#EDE3C8"))
	_poly(root, ellipse(Vector2(-64, -142), 26, 26), Color(1.0, 0.82, 0.4, 0.18))
	_poly(root, VectorIcons._scaled(VectorIcons._flame_points(), 10, Vector2(-64, -140)), Color("#FFC24A"))
	# Wax candles on the head
	for x in [-14, 0, 14]:
		_poly(root, rounded_rect(x - 3, -204, 6, 14, 2), Color("#EDE3C8"))
		_poly(root, ellipse(Vector2(x, -208), 3, 4), Color("#FFC24A"))
	_meta(root, 130, 210)


static func _mimic(root: Node2D) -> void:
	var wood := Color("#6B4A2E")
	# Chest body
	_poly(root, rounded_rect(-70, -80, 140, 80, 10), wood)
	_poly(root, rounded_rect(-70, -80, 140, 12, 4), GOLD.darkened(0.2))
	_poly(root, rounded_rect(-8, -80, 16, 80, 3), GOLD.darkened(0.2))
	# Open lid with teeth and tongue
	_poly(root, PackedVector2Array([Vector2(-74, -88), Vector2(70, -88), Vector2(60, -150), Vector2(-60, -162)]), wood.lightened(0.08))
	_poly(root, PackedVector2Array([Vector2(-60, -100), Vector2(60, -100), Vector2(52, -138), Vector2(-52, -148)]), Color("#2A0E10"))
	for i in 7:
		var x := -54 + i * 18
		_poly(root, PackedVector2Array([Vector2(x, -100), Vector2(x + 9, -116), Vector2(x + 18, -100)]), BONE)
		_poly(root, PackedVector2Array([Vector2(x, -140 + i * 0.6), Vector2(x + 9, -126), Vector2(x + 18, -140 + i * 0.6)]), BONE)
	_poly(root, ellipse(Vector2(-30, -98), 34, 10), Color("#C0465A"))
	# Coins spilling
	for c in [Vector2(-80, -8), Vector2(-62, -4), Vector2(78, -6), Vector2(-90, -2)]:
		_poly(root, ellipse(c, 10, 6), GOLD)
	# Eye on the lid
	_poly(root, ellipse(Vector2(10, -150), 12, 9), Color("#F2E6A0"))
	_poly(root, ellipse(Vector2(6, -150), 4, 7), Color.BLACK)
	_meta(root, 160, 170)


static func _hound(root: Node2D) -> void:
	var fur := Color("#3A3430")
	# Legs
	for x in [-52, -30, 30, 50]:
		_poly(root, rounded_rect(x - 7, -50, 14, 50, 5), fur.darkened(0.2))
	# Body
	_poly(root, ellipse(Vector2(0, -66), 74, 30), fur)
	_poly(root, ellipse(Vector2(10, -56), 50, 16), fur.lightened(0.08))
	# Ribs showing (undead)
	for i in 3:
		_poly(root, rounded_rect(-10 + i * 16, -80, 6, 26, 3), BONE.darkened(0.2))
	# Tail
	_poly(root, PackedVector2Array([Vector2(68, -74), Vector2(74, -66), Vector2(110, -100), Vector2(104, -106)]), fur)
	# Head facing left, glowing eye, jaw
	_poly(root, ellipse(Vector2(-78, -96), 30, 22), fur.lightened(0.05))
	_poly(root, PackedVector2Array([Vector2(-100, -100), Vector2(-136, -92), Vector2(-132, -80), Vector2(-96, -84)]), fur.lightened(0.05))
	_poly(root, PackedVector2Array([Vector2(-98, -82), Vector2(-130, -78), Vector2(-124, -68), Vector2(-96, -72)]), fur.darkened(0.15))
	_poly(root, PackedVector2Array([Vector2(-70, -114), Vector2(-60, -138), Vector2(-56, -110)]), fur)
	_poly(root, ellipse(Vector2(-88, -102), 5, 4), Color("#F2B84A"))
	_poly(root, rounded_rect(-74, -84, 18, 8, 3), GOLD)
	_meta(root, 210, 140)


static func _embalmer(root: Node2D) -> void:
	var linen := Color("#CFC3A3")
	var dark := Color("#3A2E26")
	# Long apron robe
	_poly(root, PackedVector2Array([Vector2(-48, 0), Vector2(48, 0), Vector2(34, -170), Vector2(-34, -170)]), dark)
	_poly(root, PackedVector2Array([Vector2(-30, -10), Vector2(30, -10), Vector2(22, -150), Vector2(-22, -150)]), linen.darkened(0.25))
	for i in 5:
		_poly(root, rounded_rect(-24, -140 + i * 26, 48, 5, 2), linen.darkened(0.4))
	# Wrapped head
	_poly(root, ellipse(Vector2(0, -196), 28, 32), linen)
	for i in 4:
		_poly(root, rounded_rect(-28, -218 + i * 12, 56, 4, 2), linen.darkened(0.15))
	_poly(root, rounded_rect(-16, -200, 32, 7, 3), Color("#140E0A"))
	_poly(root, ellipse(Vector2(-7, -197), 3, 3), Color("#9CCB6A"))
	# Arms: scalpel forward, jar behind
	_poly(root, PackedVector2Array([Vector2(-30, -158), Vector2(-22, -162), Vector2(-76, -118), Vector2(-82, -124)]), dark.lightened(0.1))
	_poly(root, PackedVector2Array([Vector2(-80, -122), Vector2(-76, -118), Vector2(-112, -140), Vector2(-114, -144)]), Color("#C9D2E3"))
	_poly(root, rounded_rect(44, -120, 26, 34, 6), Color(GOLD, 0.8))
	_poly(root, rounded_rect(44, -126, 26, 8, 3), dark)
	_meta(root, 150, 240)


static func _knight(root: Node2D) -> void:
	var plate := Color("#B8923A")
	var dark := Color("#4A3A22")
	# Legs
	_poly(root, rounded_rect(-44, -84, 32, 84, 8), dark)
	_poly(root, rounded_rect(14, -84, 32, 84, 8), dark)
	_poly(root, rounded_rect(-48, -40, 40, 14, 4), plate)
	_poly(root, rounded_rect(10, -40, 40, 14, 4), plate)
	# Cuirass
	_poly(root, PackedVector2Array([Vector2(-62, -80), Vector2(62, -80), Vector2(74, -190), Vector2(-74, -190)]), plate)
	_poly(root, PackedVector2Array([Vector2(0, -80), Vector2(62, -80), Vector2(74, -190), Vector2(0, -190)]), plate.darkened(0.15))
	_poly(root, VectorIcons._scaled(VectorIcons._star(4, 1.0, 0.4), 18, Vector2(0, -140)), Color("#FFF1B8"))
	_poly(root, ellipse(Vector2(-74, -186), 32, 22), plate.lightened(0.1))
	_poly(root, ellipse(Vector2(74, -186), 32, 22), plate.lightened(0.1))
	# Great helm with plume
	_poly(root, rounded_rect(-34, -262, 68, 78, 16), plate.lightened(0.05))
	_poly(root, rounded_rect(-26, -232, 52, 8, 3), Color("#1A140C"))
	_poly(root, rounded_rect(-3, -248, 6, 40, 2), Color("#1A140C"))
	_poly(root, PackedVector2Array([Vector2(-6, -262), Vector2(6, -262), Vector2(40, -300), Vector2(20, -306)]), Color("#A3283A"))
	# Greatsword held forward (left)
	_poly(root, PackedVector2Array([Vector2(-80, -150), Vector2(-70, -146), Vector2(-150, -300), Vector2(-162, -296)]), Color("#E6E1D2"))
	_poly(root, rounded_rect(-100, -160, 44, 12, 4), plate.darkened(0.3))
	_meta(root, 210, 300)


static func _reliquary(root: Node2D, glow: Color) -> void:
	var stone := Color("#4A4036")
	# Plinth
	_poly(root, rounded_rect(-60, -40, 120, 40, 6), stone)
	_poly(root, rounded_rect(-70, -52, 140, 14, 4), stone.lightened(0.1))
	# Floating shrine box
	var bob := -20.0
	_poly(root, rounded_rect(-50, -170 + bob, 100, 100, 10), GOLD.darkened(0.25))
	_poly(root, rounded_rect(-40, -160 + bob, 80, 80, 8), GOLD.darkened(0.05))
	_poly(root, PackedVector2Array([Vector2(-58, -170 + bob), Vector2(58, -170 + bob), Vector2(0, -214 + bob)]), GOLD.darkened(0.3))
	# Glowing relic heart
	_poly(root, ellipse(Vector2(0, -120 + bob), 40, 40), Color(glow, 0.22))
	_poly(root, ellipse(Vector2(0, -120 + bob), 18, 18), glow)
	_poly(root, ellipse(Vector2(-4, -124 + bob), 7, 7), glow.lightened(0.5))
	_meta(root, 150, 230)


static func _censer(root: Node2D) -> void:
	var robe := Color("#3A4A2A")
	var brass := Color("#A88A4A")
	# Hulking robed body
	_poly(root, PackedVector2Array([Vector2(-70, 0), Vector2(70, 0), Vector2(50, -170), Vector2(-50, -170)]), robe)
	_poly(root, ellipse(Vector2(0, -180), 56, 30), robe.darkened(0.15))
	# Plague mask with beak (facing left)
	_poly(root, ellipse(Vector2(0, -210), 30, 32), Color("#2A2A22"))
	_poly(root, PackedVector2Array([Vector2(-20, -214), Vector2(-74, -196), Vector2(-20, -196)]), Color("#C9BFA0"))
	_poly(root, ellipse(Vector2(-10, -218), 7, 7), Color("#9CCB6A"))
	# Chain and swinging censer
	_poly(root, PackedVector2Array([Vector2(-40, -130), Vector2(-36, -126), Vector2(-96, -60), Vector2(-100, -64)]), brass.darkened(0.3))
	_poly(root, ellipse(Vector2(-104, -52), 24, 20), brass)
	_poly(root, rounded_rect(-114, -76, 20, 10, 3), brass.darkened(0.2))
	for k in 4:
		_poly(root, ellipse(Vector2(-104 + k * 10, -90 - k * 22), 12 + k * 3, 10 + k * 2), Color(0.6, 0.8, 0.4, 0.22 - k * 0.04))
	_meta(root, 190, 250)


static func _hierophant(root: Node2D) -> void:
	var robe := Color("#F2E3B8")
	var trim := GOLD
	# Halo
	_poly(root, ellipse(Vector2(0, -280), 70, 70), Color(trim, 0.25))
	_poly(root, ellipse(Vector2(0, -280), 56, 56), Color(trim, 0.12))
	# Vast robes
	_poly(root, PackedVector2Array([Vector2(-110, 0), Vector2(110, 0), Vector2(56, -230), Vector2(-56, -230)]), robe)
	_poly(root, PackedVector2Array([Vector2(-20, 0), Vector2(20, 0), Vector2(14, -230), Vector2(-14, -230)]), trim)
	for i in 4:
		_poly(root, rounded_rect(-100 + i * 6, -30 - i * 50, 200 - i * 12, 8, 3), trim.darkened(0.15))
	# Masked face and tall mitre
	_poly(root, ellipse(Vector2(0, -256), 34, 38), trim.lightened(0.2))
	_poly(root, ellipse(Vector2(-12, -258), 6, 4), Color("#1A140C"))
	_poly(root, ellipse(Vector2(12, -258), 6, 4), Color("#1A140C"))
	_poly(root, PackedVector2Array([Vector2(-40, -286), Vector2(40, -286), Vector2(22, -370), Vector2(0, -392), Vector2(-22, -370)]), robe)
	_poly(root, rounded_rect(-4, -380, 8, 90, 3), trim)
	# Sceptre (forward = left)
	_poly(root, rounded_rect(-120, -300, 10, 300, 4), trim.darkened(0.2))
	_poly(root, VectorIcons._scaled(VectorIcons._star(8, 1.0, 0.5), 30, Vector2(-115, -310)), trim)
	_poly(root, ellipse(Vector2(-115, -310), 12, 12), Color("#FFF1B8"))
	_meta(root, 240, 400)


static func _idol(root: Node2D) -> void:
	var g := GOLD
	_poly(root, rounded_rect(-44, -30, 88, 30, 6), Color("#4A4036"))
	_poly(root, PackedVector2Array([Vector2(-34, -30), Vector2(34, -30), Vector2(24, -130), Vector2(-24, -130)]), g.darkened(0.15))
	_poly(root, ellipse(Vector2(0, -150), 30, 30), g)
	_poly(root, ellipse(Vector2(-10, -152), 6, 4), Color("#5A3A10"))
	_poly(root, ellipse(Vector2(10, -152), 6, 4), Color("#5A3A10"))
	_poly(root, rounded_rect(-10, -138, 20, 4, 2), Color("#5A3A10"))
	_poly(root, ellipse(Vector2(0, -150), 46, 46), Color(g, 0.15))
	_meta(root, 110, 190)



static func _scribe(root: Node2D) -> void:
	var ink := Color("#1C2230")
	var parchment := Color("#E9DFC7")
	var crimson := Color("#A3283A")
	# Loose pages orbiting behind
	for p in [Vector2(-70, -230), Vector2(60, -250), Vector2(-90, -150)]:
		var page := PackedVector2Array([p + Vector2(-12, -16), p + Vector2(12, -12), p + Vector2(10, 14), p + Vector2(-14, 10)])
		_poly(root, page, Color(parchment, 0.8))
	# Long robe
	_poly(root, PackedVector2Array([Vector2(-52, 0), Vector2(52, 0), Vector2(30, -176), Vector2(-30, -176)]), ink)
	_poly(root, PackedVector2Array([Vector2(-8, 0), Vector2(8, 0), Vector2(6, -170), Vector2(-6, -170)]), crimson.darkened(0.2))
	# Ink-stained hem
	for x in [-40, -18, 14, 36]:
		_poly(root, ellipse(Vector2(x, -6), 10, 8), Color("#0E1018"))
	# Hood with an empty, glowing face
	_poly(root, ellipse(Vector2(0, -200), 32, 36), ink.lightened(0.08))
	_poly(root, PackedVector2Array([Vector2(-30, -196), Vector2(0, -246), Vector2(30, -196)]), ink.lightened(0.08))
	_poly(root, ellipse(Vector2(2, -194), 18, 22), Color("#07080C"))
	_poly(root, ellipse(Vector2(-6, -196), 3, 4), Color("#8FB4E8"))
	_poly(root, ellipse(Vector2(8, -196), 3, 4), Color("#8FB4E8"))
	# Quill-staff (front)
	_poly(root, rounded_rect(54, -230, 8, 230, 3), Color("#5A4030"))
	_poly(root, PackedVector2Array([Vector2(58, -230), Vector2(86, -300), Vector2(66, -236)]), parchment)
	# Floating tome at the shoulder, open, with a crimson ribbon
	_poly(root, PackedVector2Array([Vector2(-100, -170), Vector2(-64, -162), Vector2(-64, -128), Vector2(-100, -136)]), parchment)
	_poly(root, PackedVector2Array([Vector2(-64, -162), Vector2(-28, -170), Vector2(-28, -136), Vector2(-64, -128)]), parchment.darkened(0.08))
	_poly(root, rounded_rect(-66, -164, 4, 40, 1), Color("#5A4030"))
	_poly(root, rounded_rect(-50, -132, 4, 28, 1), crimson)
	for i in 3:
		_poly(root, rounded_rect(-94, -156 + i * 8, 24, 2, 1), Color(ink, 0.6))
	_meta(root, 200, 280)


# --- Act 3: The Shattered Observatory ------------------------------------------------

const BRASS := Color("#B8893E")
const STARLIGHT := Color("#E9E4FF")


static func _gear(root: Node2D, c: Vector2, r: float, teeth: int, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in teeth * 2:
		var a := PI * i / teeth
		var rr := r if i % 2 == 0 else r * 0.78
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	_poly(root, pts, color)
	_poly(root, ellipse(c, r * 0.35, r * 0.35), color.darkened(0.4))


static func _sentinel(root: Node2D) -> void:
	var steel := Color("#5A5F6E")
	_poly(root, rounded_rect(-40, -60, 26, 60, 6), steel.darkened(0.2))
	_poly(root, rounded_rect(14, -60, 26, 60, 6), steel.darkened(0.2))
	_poly(root, rounded_rect(-56, -170, 112, 116, 14), steel)
	_gear(root, Vector2(0, -114), 30, 10, BRASS)
	_poly(root, rounded_rect(-34, -224, 68, 54, 12), steel.lightened(0.1))
	_poly(root, ellipse(Vector2(-6, -198), 16, 10), Color("#FF5A3A"))
	_poly(root, ellipse(Vector2(-8, -198), 6, 6), Color("#FFE0A0"))
	# Arm cannon forward
	_poly(root, rounded_rect(-112, -150, 70, 26, 8), steel.darkened(0.1))
	_poly(root, ellipse(Vector2(-114, -137), 10, 13), Color("#FF8A3A"))
	_meta(root, 180, 230)


static func _shard(root: Node2D) -> void:
	var c := Color("#9FB8FF")
	_poly(root, ellipse(Vector2(0, -80), 46, 46), Color(c, 0.15))
	_poly(root, PackedVector2Array([Vector2(0, -150), Vector2(30, -80), Vector2(0, -20), Vector2(-30, -80)]), c)
	_poly(root, PackedVector2Array([Vector2(0, -150), Vector2(30, -80), Vector2(0, -80)]), c.lightened(0.4))
	_poly(root, ellipse(Vector2(0, -80), 7, 7), STARLIGHT)
	_meta(root, 90, 160)


static func _harpy(root: Node2D) -> void:
	var feather := Color("#4A5A7A")
	# Wings spread
	_poly(root, PackedVector2Array([Vector2(-10, -150), Vector2(-120, -210), Vector2(-150, -150), Vector2(-90, -130), Vector2(-120, -110), Vector2(-20, -110)]), feather.darkened(0.1))
	_poly(root, PackedVector2Array([Vector2(10, -150), Vector2(120, -220), Vector2(150, -160), Vector2(90, -136), Vector2(120, -112), Vector2(20, -110)]), feather.darkened(0.2))
	_poly(root, ellipse(Vector2(0, -130), 30, 44), feather)
	_poly(root, ellipse(Vector2(0, -186), 20, 22), Color("#C9B8A0"))
	_poly(root, PackedVector2Array([Vector2(-18, -184), Vector2(-36, -176), Vector2(-18, -176)]), Color("#E8B84A"))
	_poly(root, ellipse(Vector2(-6, -190), 4, 3), Color("#9FD3F0"))
	for x in [-14, 14]:
		_poly(root, PackedVector2Array([Vector2(x - 6, -90), Vector2(x + 6, -90), Vector2(x, -62)]), Color("#E8B84A"))
	_meta(root, 260, 230)


static func _leech(root: Node2D) -> void:
	var body := Color("#2A1A3A")
	var pts := PackedVector2Array()
	for i in 21:
		var t := float(i) / 20.0
		pts.append(Vector2(lerpf(90, -90, t), -40 - sin(t * PI) * 70 - sin(t * TAU * 2) * 6))
	for i in 21:
		var t := 1.0 - float(i) / 20.0
		pts.append(Vector2(lerpf(90, -90, t), -10 - sin(t * PI) * 20))
	_poly(root, pts, body)
	for i in 5:
		_poly(root, ellipse(Vector2(-60 + i * 30, -60 - sin((i + 0.5) / 5.0 * PI) * 50), 6, 4), Color("#B04AD0"))
	# Round sucker mouth facing left
	_poly(root, ellipse(Vector2(-92, -46), 22, 22), body.lightened(0.1))
	_poly(root, ellipse(Vector2(-94, -46), 13, 13), Color("#7A1A3A"))
	for k in 8:
		var a := k * TAU / 8
		_poly(root, ellipse(Vector2(-94, -46) + Vector2(cos(a), sin(a)) * 10, 2, 2), Color("#E8E0D0"))
	_meta(root, 200, 130)


static func _weaver(root: Node2D) -> void:
	var robe := Color("#2A2F5E")
	# Threads of light behind
	for i in 6:
		var x := -60 + i * 24
		_poly(root, PackedVector2Array([Vector2(x, -260), Vector2(x + 2, -260), Vector2(x + 30, 0), Vector2(x + 28, 0)]), Color(STARLIGHT, 0.18))
	_poly(root, PackedVector2Array([Vector2(-60, 0), Vector2(60, 0), Vector2(26, -180), Vector2(-26, -180)]), robe)
	# Four arms holding a loom frame
	for y in [-150, -120]:
		_poly(root, PackedVector2Array([Vector2(-22, y), Vector2(-18, y + 6), Vector2(-80, y + 20), Vector2(-82, y + 12)]), robe.lightened(0.15))
		_poly(root, PackedVector2Array([Vector2(22, y), Vector2(18, y + 6), Vector2(80, y + 20), Vector2(82, y + 12)]), robe.lightened(0.15))
	_poly(root, rounded_rect(-96, -150, 8, 70, 3), BRASS)
	_poly(root, rounded_rect(88, -150, 8, 70, 3), BRASS)
	# Masked face with a clock
	_poly(root, ellipse(Vector2(0, -204), 28, 30), STARLIGHT.darkened(0.1))
	_poly(root, ellipse(Vector2(0, -204), 16, 16), robe.darkened(0.3))
	_poly(root, rounded_rect(-1, -216, 2, 13, 1), BRASS)
	_poly(root, rounded_rect(-1, -205, 10, 2, 1), BRASS)
	_meta(root, 200, 260)


static func _chronomancer(root: Node2D) -> void:
	var iron := Color("#3E3A4A")
	_poly(root, rounded_rect(-70, -70, 40, 70, 8), iron.darkened(0.2))
	_poly(root, rounded_rect(30, -70, 40, 70, 8), iron.darkened(0.2))
	_poly(root, rounded_rect(-90, -220, 180, 160, 20), iron)
	_gear(root, Vector2(-30, -160), 34, 12, BRASS)
	_gear(root, Vector2(36, -128), 26, 10, BRASS.darkened(0.2))
	# Clock-face head
	_poly(root, ellipse(Vector2(0, -260), 44, 44), STARLIGHT.darkened(0.15))
	_poly(root, ellipse(Vector2(0, -260), 38, 38), Color("#1A1830"))
	for k in 12:
		var a := k * TAU / 12
		_poly(root, ellipse(Vector2(0, -260) + Vector2(cos(a), sin(a)) * 32, 2.5, 2.5), BRASS)
	_poly(root, rounded_rect(-2, -288, 4, 30, 2), Color("#FF8A3A"))
	_poly(root, rounded_rect(-2, -262, 22, 4, 2), STARLIGHT)
	# Pendulum arm
	_poly(root, rounded_rect(-140, -190, 52, 22, 8), iron.lightened(0.1))
	_poly(root, ellipse(Vector2(-142, -150), 18, 18), BRASS)
	_poly(root, rounded_rect(-145, -178, 6, 28, 2), BRASS.darkened(0.3))
	_meta(root, 260, 310)


static func _seraph(root: Node2D) -> void:
	var gold := Color("#F2D98A")
	for i in 3:
		var a := -PI / 2 + (i - 1) * 0.5
		_poly(root, PackedVector2Array([Vector2(0, -170), Vector2(cos(a - 0.5) * 170, -170 + sin(a - 0.5) * 120),
			Vector2(cos(a) * 200, -170 + sin(a) * 150)]), Color(STARLIGHT, 0.35 - i * 0.05))
		_poly(root, PackedVector2Array([Vector2(0, -170), Vector2(-cos(a - 0.5) * 170, -170 + sin(a - 0.5) * 120),
			Vector2(-cos(a) * 200, -170 + sin(a) * 150)]), Color(STARLIGHT, 0.35 - i * 0.05))
	_poly(root, PackedVector2Array([Vector2(-40, -10), Vector2(40, -10), Vector2(24, -200), Vector2(-24, -200)]), STARLIGHT)
	_poly(root, ellipse(Vector2(0, -224), 22, 26), gold.lightened(0.3))
	_poly(root, rounded_rect(-14, -228, 28, 5, 2), Color("#3A3A6A"))
	_poly(root, PackedVector2Array([Vector2(-60, -150), Vector2(-50, -146), Vector2(-150, -40), Vector2(-160, -46)]), gold)
	_meta(root, 260, 290)


static func _halo_fragment(root: Node2D) -> void:
	var gold := Color("#F2D98A")
	_poly(root, ellipse(Vector2(0, -90), 40, 40), Color(gold, 0.16))
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * 0.6 * i / 12.0
		pts.append(Vector2(cos(a) * 34, -90 + sin(a) * 34))
	for i in 13:
		var a := PI + PI * 0.6 * (12 - i) / 12.0
		pts.append(Vector2(cos(a) * 24, -90 + sin(a) * 24))
	_poly(root, pts, gold)
	_poly(root, ellipse(Vector2(-22, -112), 5, 5), STARLIGHT)
	_meta(root, 90, 140)


static func _orrery(root: Node2D) -> void:
	# Pedestal
	_poly(root, rounded_rect(-90, -40, 180, 40, 10), BRASS.darkened(0.4))
	_poly(root, rounded_rect(-14, -200, 28, 160, 6), BRASS.darkened(0.2))
	# Rings
	for k in 3:
		var r := 90.0 + k * 40.0
		var pts := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in 49:
			var a := TAU * i / 48.0
			pts.append(Vector2(cos(a) * r, -230 + sin(a) * r * 0.35))
			inner.append(Vector2(cos(a) * (r - 6), -230 + sin(a) * (r - 6) * 0.35))
		inner.reverse()
		pts.append_array(inner)
		_poly(root, pts, Color(BRASS, 0.8 - k * 0.15))
	# Sun core and three planets
	_poly(root, ellipse(Vector2(0, -230), 70, 70), Color("#FF8A3A", 0.2))
	_poly(root, ellipse(Vector2(0, -230), 46, 46), Color("#FFB45A"))
	_poly(root, ellipse(Vector2(-8, -238), 20, 20), Color("#FFE3A0"))
	_poly(root, ellipse(Vector2(-90, -230), 18, 18), Color("#D9573A"))
	_poly(root, ellipse(Vector2(124, -250), 16, 16), Color("#E8D9A6"))
	_poly(root, ellipse(Vector2(40, -190), 22, 22), Color("#C9A86A"))
	_poly(root, ellipse(Vector2(40, -190), 34, 8), Color("#C9A86A", 0.6))
	_meta(root, 340, 340)
