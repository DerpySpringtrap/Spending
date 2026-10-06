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
