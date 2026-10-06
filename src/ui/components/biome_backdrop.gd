class_name BiomeBackdrop
extends Control
## Flat vector battle backdrop per act: sky gradient, moon, layered hills,
## silhouette trees and drifting fog. Placeholder until painted backgrounds
## exist (then swap for a TextureRect).

const PALETTES := {
	1: {"sky_top": Color("#141C24"), "sky_bottom": Color("#2C3B36"), "moon": Color("#D8E3C0"),
		"far": Color("#22302C"), "mid": Color("#1A2622"), "near": Color("#121B18"), "ground": Color("#0E1412"),
		"fog": Color("#9FB8A0")},
}

@export var act := 1
var _time := 0.0
var _trees: Array = []  # [x, height, lean]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
