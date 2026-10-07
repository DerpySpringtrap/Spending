class_name MapGenerator
extends RefCounted
## Slay the Spire–style branching act map.
##
## 15 floors × 7 columns. Six paths climb from the bottom, each step moving at
## most one column sideways without crossing an existing edge. Node types
## follow fixed rules (all fights on floor 1, treasure on floor 9, rest on
## floor 15) and weighted rolls elsewhere (no elites or rests before floor 6,
## no two elites/rests/shops in a row along a path). Every floor-15 node
## leads to the boss.
##
## The result is a JSON-safe Dictionary (string ids) stored in RunState.map_data.

const FLOORS := 15
const COLUMNS := 7
const PATHS := 6

const TYPE_MONSTER := "monster"
const TYPE_ELITE := "elite"
const TYPE_REST := "rest"
const TYPE_SHOP := "shop"
const TYPE_TREASURE := "treasure"
const TYPE_EVENT := "event"
const TYPE_BOSS := "boss"

const WEIGHTS := {TYPE_MONSTER: 45, TYPE_EVENT: 22, TYPE_ELITE: 16, TYPE_REST: 12, TYPE_SHOP: 5}
const NO_REPEAT := [TYPE_ELITE, TYPE_REST, TYPE_SHOP]


static func node_id(floor_index: int, col: int) -> String:
	return "%d_%d" % [floor_index, col]


## [param ascension] >= AscensionRules.ELITE_SPAWN_BONUS_LEVEL makes elites ~40% more common.
static func generate(rng: RandomNumberGenerator, act: int = 1, ascension: int = 0) -> Dictionary:
	var nodes := {}
	var edges := {}  # id -> Array[String]
	var starts: Array[int] = []
	for p in PATHS:
		var col := rng.randi_range(0, COLUMNS - 1)
		if p == 1:
			while starts.size() > 0 and col == starts[0]:
				col = rng.randi_range(0, COLUMNS - 1)
		starts.append(col)
		for f in FLOORS:
			var id := node_id(f, col)
			if not nodes.has(id):
				nodes[id] = {"id": id, "floor": f, "col": col, "type": "", "next": []}
			if f == FLOORS - 1:
				break
			var next_col := clampi(col + rng.randi_range(-1, 1), 0, COLUMNS - 1)
			# Don't cross an existing edge between the same two floors.
			if next_col == col + 1 and _has_edge(edges, node_id(f, col + 1), node_id(f + 1, col)):
				next_col = col
			elif next_col == col - 1 and _has_edge(edges, node_id(f, col - 1), node_id(f + 1, col)):
				next_col = col
			var next_id := node_id(f + 1, next_col)
			if not edges.has(id):
				edges[id] = []
			if not edges[id].has(next_id):
				edges[id].append(next_id)
			col = next_col
	for id in edges:
		nodes[id].next = edges[id]

	var boss_id := node_id(FLOORS, COLUMNS / 2)
	nodes[boss_id] = {"id": boss_id, "floor": FLOORS, "col": COLUMNS / 2, "type": TYPE_BOSS, "next": []}
	for id in nodes:
		if nodes[id].floor == FLOORS - 1:
			nodes[id].next = [boss_id]

	_assign_types(nodes, rng, ascension)
	return {"act": act, "floors": FLOORS, "columns": COLUMNS, "nodes": nodes, "boss": boss_id}


## The short final act: rest → shop → elite → boss, one path.
static func generate_final(act: int) -> Dictionary:
	var nodes := {}
	var col := COLUMNS / 2
	var types := [TYPE_REST, TYPE_SHOP, TYPE_ELITE]
	for f in types.size():
		var id := node_id(f, col)
		nodes[id] = {"id": id, "floor": f, "col": col, "type": types[f], "next": [node_id(f + 1, col)]}
	var boss_id := node_id(types.size(), col)
	nodes[boss_id] = {"id": boss_id, "floor": types.size(), "col": col, "type": TYPE_BOSS, "next": []}
	return {"act": act, "floors": types.size(), "columns": COLUMNS, "nodes": nodes, "boss": boss_id}


static func _has_edge(edges: Dictionary, from: String, to: String) -> bool:
	return edges.has(from) and edges[from].has(to)


static func _assign_types(nodes: Dictionary, rng: RandomNumberGenerator, ascension: int = 0) -> void:
	var parents := {}  # id -> Array of parent ids
	for id in nodes:
		for next_id in nodes[id].next:
			if not parents.has(next_id):
				parents[next_id] = []
			parents[next_id].append(id)
	var ids := nodes.keys()
	ids.sort_custom(func(a, b): return nodes[a].floor < nodes[b].floor)
	for id in ids:
		var node: Dictionary = nodes[id]
		if node.type != "":
			continue
		match int(node.floor):
			0:
				node.type = TYPE_MONSTER
			8:
				node.type = TYPE_TREASURE
			14:
				node.type = TYPE_REST
			_:
				node.type = _roll_type(node, parents.get(id, []), nodes, rng, ascension)


static func _roll_type(node: Dictionary, parent_ids: Array, nodes: Dictionary, rng: RandomNumberGenerator,
		ascension: int = 0) -> String:
	var parent_types := parent_ids.map(func(p): return nodes[p].type)
	var weights := WEIGHTS.duplicate()
	if ascension >= AscensionRules.ELITE_SPAWN_BONUS_LEVEL:
		weights[TYPE_ELITE] = roundi(weights[TYPE_ELITE] * 1.4)
	for attempt in 20:
		var total := 0
		for t in weights:
			total += weights[t]
		var roll := rng.randi_range(1, total)
		var chosen := TYPE_MONSTER
		for t in weights:
			roll -= weights[t]
			if roll <= 0:
				chosen = t
				break
		if (chosen == TYPE_ELITE or chosen == TYPE_REST) and node.floor < 5:
			continue
		if chosen == TYPE_REST and node.floor == 13:
			continue  # Floor 15 is always a rest site.
		if chosen in NO_REPEAT and parent_types.has(chosen):
			continue
		return chosen
	return TYPE_MONSTER


## Nodes the player may travel to next.
static func reachable(map: Dictionary, current: String) -> Array[String]:
	var out: Array[String] = []
	if map.is_empty():
		return out
	if current == "":
		for id in map.nodes:
			if int(map.nodes[id].floor) == 0:
				out.append(id)
	elif map.nodes.has(current):
		for id in map.nodes[current].next:
			out.append(String(id))
	out.sort()
	return out
