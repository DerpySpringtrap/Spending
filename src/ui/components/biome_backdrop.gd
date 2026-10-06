class_name BiomeBackdrop
extends Control
## Flat vector battle backdrop per act: sky gradient, moon, layered hills,
## silhouette trees and drifting fog. Placeholder until painted backgrounds
## exist (then swap for a TextureRect).

const PALETTES := {
	1: {"sky_top": Color("#141C24"), "sky_bottom": Color("#2C3B36"), "moon": Color("#D8E3C0"),
		"far": Color("#22302C"), "mid": Color("#1A2622"), "near": Color("#121B18"), "ground": Color("#0E1412"),
		"fog": Color("#9FB8A0")},
	2: {"sky_top": Color("#17120E"), "sky_bottom": Color("#3A2C1C"), "moon": Color("#F2C46B"),
		"far": Color("#2A2018"), "mid": Color("#211912"), "near": Color("#16100B"), "ground": Color("#110C08"),
		"fog": Color("#E8C27A")},
}

## 0 = the current run's act (1 outside a run).
@export var act := 0
var _time := 0.0
var _trees: Array = []  # [x, height, lean]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if act <= 0:
		act = RunState.act if RunState.active else 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + act
	for i in 9:
		_trees.append([rng.randf(), rng.randf_range(0.18, 0.34), rng.randf_range(-0.08, 0.08)])
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var p: Dictionary = PALETTES.get(act, PALETTES[1])
	if act == 2:
		_draw_crypt(p)
		return
	var w := size.x
	var h := size.y
	var bands := 24
	for i in bands:
		var c: Color = p.sky_top.lerp(p.sky_bottom, float(i) / bands)
		draw_rect(Rect2(0, h * 0.7 * i / bands, w, h * 0.7 / bands + 1), c)
	var moon := Vector2(w * 0.72, h * 0.16)
	draw_circle(moon, 120, Color(p.moon, 0.06))
	draw_circle(moon, 70, Color(p.moon, 0.1))
	draw_circle(moon, 44, p.moon)
	draw_circle(moon + Vector2(14, -8), 40, p.sky_top.lerp(p.sky_bottom, 0.15))
	_hills(p.far, h * 0.46, 50.0, 0.004, 1.3)
	for tree in _trees:
		_tree(Vector2(w * tree[0], h * 0.58), h * tree[1], tree[2], p.mid)
	_hills(p.mid, h * 0.56, 34.0, 0.007, 4.1)
	draw_rect(Rect2(0, h * 0.66, w, h * 0.34), p.ground)
	_hills(p.near, h * 0.64, 20.0, 0.011, 2.2)
	for i in 3:
		var y := h * (0.5 + i * 0.07)
		var drift := fmod(_time * (8.0 + i * 5.0), w)
		for k in 2:
			draw_rect(Rect2(drift - w * k, y, w * 0.7, 18 + i * 6), Color(p.fog, 0.035 + i * 0.01))


func _hills(color: Color, base: float, amp: float, freq: float, phase: float) -> void:
	var pts := PackedVector2Array()
	var steps := 48
	for i in steps + 1:
		var x := size.x * i / steps
		pts.append(Vector2(x, base - amp * (sin(x * freq + phase) * 0.6 + sin(x * freq * 2.3 + phase * 1.7) * 0.4)))
	pts.append(Vector2(size.x, size.y))
	pts.append(Vector2(0, size.y))
	draw_colored_polygon(pts, color)


func _tree(foot: Vector2, height: float, lean: float, color: Color) -> void:
	var top := foot + Vector2(lean * height, -height)
	draw_colored_polygon(PackedVector2Array([foot + Vector2(-9, 0), foot + Vector2(9, 0), top + Vector2(2, 0), top + Vector2(-2, 0)]), color)
	for k in 4:
		var t := 0.35 + k * 0.15
		var origin := foot.lerp(top, t)
		var dir := Vector2(1 if k % 2 == 0 else -1, -0.7).normalized()
		draw_line(origin, origin + dir * height * (0.28 - k * 0.04), color, 5.0 - k)


## Act 2: a gilded crypt hall. Arches and pillars recede into candlelit gloom.
func _draw_crypt(p: Dictionary) -> void:
	var w := size.x
	var h := size.y
	var bands := 24
	for i in bands:
		var c: Color = p.sky_top.lerp(p.sky_bottom, float(i) / bands)
		draw_rect(Rect2(0, h * 0.7 * i / bands, w, h * 0.7 / bands + 1), c)
	# Distant glow of a golden altar
	var glow := Vector2(w * 0.72, h * 0.3)
	for k in 4:
		draw_circle(glow, 260 - k * 55, Color(p.moon, 0.025 + k * 0.012))
	# Far arcade: arches
	var arch_w := w / 7.0
	for i in 8:
		var x := i * arch_w - arch_w * 0.3
		_arch(Vector2(x, h * 0.62), arch_w * 0.8, h * 0.34, p.far)
	# Mid pillars with gold bands
	for i in 5:
		var x := w * (0.08 + i * 0.22)
		var top := h * 0.12
		draw_rect(Rect2(x - 26, top, 52, h * 0.56), p.mid)
		draw_rect(Rect2(x - 34, top - 14, 68, 18), p.mid.lightened(0.05))
		draw_rect(Rect2(x - 34, h * 0.64, 68, 16), p.mid.lightened(0.05))
		draw_rect(Rect2(x - 26, top + 40, 52, 5), Color(p.moon, 0.35))
		draw_rect(Rect2(x - 26, h * 0.55, 52, 5), Color(p.moon, 0.25))
	# Floor with flagstone lines
	draw_rect(Rect2(0, h * 0.66, w, h * 0.34), p.ground)
	for i in 6:
		var y := h * (0.68 + i * 0.055)
		draw_line(Vector2(0, y), Vector2(w, y), Color(p.far, 0.6), 2.0)
	# Candles along the far wall, flickering
	for i in 9:
		var x := w * (0.05 + i * 0.11)
		var y := h * 0.6
		draw_rect(Rect2(x - 4, y - 18, 8, 18), Color("#D9C9A8"))
		var flicker := 0.75 + 0.25 * sin(_time * 7.0 + i * 1.7)
		draw_circle(Vector2(x, y - 24), 16 * flicker, Color(p.moon, 0.12))
		draw_circle(Vector2(x, y - 24), 4.5 * flicker, Color("#FFE3A0"))
	# Drifting gold dust instead of fog
	for i in 26:
		var seed_x := fmod(i * 0.6180339 * w + _time * (6.0 + i % 5), w)
		var seed_y := h * (0.2 + fmod(i * 0.37, 0.5)) + sin(_time * 0.8 + i) * 12.0
		draw_circle(Vector2(seed_x, seed_y), 1.6 + (i % 3) * 0.6, Color(p.fog, 0.18))


func _arch(foot: Vector2, width: float, height: float, color: Color) -> void:
	var pts := PackedVector2Array()
	var r := width / 2.0
	pts.append(foot)
	pts.append(foot + Vector2(0, -height + r))
	for k in 13:
		var a := PI + PI * k / 12.0
		pts.append(foot + Vector2(r + cos(a) * r, -height + r + sin(a) * r))
	pts.append(foot + Vector2(width, 0))
	draw_polyline(pts, color, 14.0)
