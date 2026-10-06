class_name TargetingArrow
extends Control
## Bezier targeting arrow for single-target cards: a stream of marching dots
## that grow toward an arrowhead. Turns from gold to red and shows a reticle
## when over a valid target.

const SEGMENTS := 16

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _locked := false
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	z_index = 200


func show_between(from_global: Vector2, to_global: Vector2, locked: bool) -> void:
	_from = from_global - global_position
	_to = to_global - global_position
	_locked = locked
	visible = true
	queue_redraw()


func hide_arrow() -> void:
	visible = false


func _process(delta: float) -> void:
	if visible:
		_time += delta
		queue_redraw()


func _point(t: float, control: Vector2) -> Vector2:
	return _from.lerp(control, t).lerp(control.lerp(_to, t), t)


func _draw() -> void:
	var distance := _from.distance_to(_to)
	if distance < 8.0:
		return
	var control := (_from + _to) / 2 + Vector2(0, -maxf(100.0, distance * 0.4))
	var color := UIStyle.DAMAGE if _locked else UIStyle.GOLD
	var phase := fmod(_time * 1.6, 1.0)
	for i in SEGMENTS:
		var t := (i + phase) / SEGMENTS
		if t > 0.94:
			continue
		var p := _point(t, control)
		var radius := lerpf(3.5, 9.0, t)
		draw_circle(p, radius + 2.5, UIStyle.OUTLINE)
		draw_circle(p, radius, color)
	# Arrowhead aligned to the curve's tangent at the end.
	var dir := (_to - _point(0.95, control)).normalized()
	var side := dir.orthogonal()
	var head := PackedVector2Array([_to + dir * 6, _to - dir * 30 + side * 20, _to - dir * 30 - side * 20])
	var outline := PackedVector2Array([_to + dir * 11, _to - dir * 34 + side * 25, _to - dir * 34 - side * 25])
	draw_colored_polygon(outline, UIStyle.OUTLINE)
	draw_colored_polygon(head, color)
