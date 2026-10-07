class_name MapView
extends Control
## Draws the act map (paths + node buttons) inside a ScrollContainer.
## Bottom = floor 1, top = boss.

signal node_chosen(node_id: String)

const FLOOR_SPACING := 112.0
const WIDTH := 1000.0
const MARGIN_BOTTOM := 110.0
const MARGIN_TOP := 220.0
const FOG_AHEAD := 3

var map: Dictionary = {}
var current := ""
var visited: Array = []
var buttons: Dictionary = {}  # id -> MapNodeButton
var _reachable: Array[String] = []


func build(p_map: Dictionary, p_current: String, p_visited: Array) -> void:
	map = p_map
	current = p_current
	visited = p_visited
	_reachable = MapGenerator.reachable(map, current)
	custom_minimum_size = Vector2(WIDTH, MARGIN_BOTTOM + MARGIN_TOP + FLOOR_SPACING * int(map.get("floors", MapGenerator.FLOORS)))
	size = custom_minimum_size
	var current_floor := -1 if current == "" else int(map.nodes[current].floor)
	for id in map.nodes:
		var node: Dictionary = map.nodes[id]
		var is_boss := String(node.type) == MapGenerator.TYPE_BOSS
		var b := MapNodeButton.new().setup(id, node.type, is_boss)
		b.reachable = _reachable.has(id)
		b.visited = visited.has(id)
		b.current = id == current
		b.fogged = not is_boss and int(node.floor) > current_floor + FOG_AHEAD
		b.position = node_position(id) - b.size / 2
		b.chosen.connect(func(nid): node_chosen.emit(nid))
		add_child(b)
		buttons[id] = b
	queue_redraw()


func node_position(id: String) -> Vector2:
	var node: Dictionary = map.nodes[id]
	var f := int(node.floor)
	var y := size.y - MARGIN_BOTTOM - f * FLOOR_SPACING
	if String(node.type) == MapGenerator.TYPE_BOSS:
		return Vector2(WIDTH / 2, y - 40)
	var col := int(node.col)
	var jitter := Vector2(float(hash(id) % 29) - 14.0, float(hash(id + "y") % 21) - 10.0)
	return Vector2(90 + col * (WIDTH - 180) / (MapGenerator.COLUMNS - 1), y) + jitter


func reachable_buttons() -> Array:
	return _reachable.map(func(id): return buttons[id])


func floor_y(f: int) -> float:
	return size.y - MARGIN_BOTTOM - f * FLOOR_SPACING


func _draw() -> void:
	if map.is_empty():
		return
	var current_floor := -1 if current == "" else int(map.nodes[current].floor)
	for id in map.nodes:
		var from := node_position(id)
		for next_id in map.nodes[id].next:
			var to := node_position(next_id)
			var dir := (to - from).normalized()
			var a := from + dir * 34
			var b := to - dir * (80 if String(map.nodes[next_id].type) == MapGenerator.TYPE_BOSS else 34)
			var travelled: bool = visited.has(id) and visited.has(next_id) and visited.find(next_id) == visited.find(id) + 1
			var available: bool = id == current and _reachable.has(next_id)
			if travelled:
				draw_line(a, b, UIStyle.GOLD, 5.0, true)
			elif available:
				draw_dashed_line(a, b, UIStyle.GOLD.lerp(Color.WHITE, 0.3), 4.0, 12.0)
			else:
				var fog := int(map.nodes[id].floor) >= current_floor + FOG_AHEAD
				draw_dashed_line(a, b, Color(1, 1, 1, 0.08 if fog else 0.22), 3.0, 10.0)
