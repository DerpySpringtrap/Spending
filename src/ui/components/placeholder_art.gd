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
