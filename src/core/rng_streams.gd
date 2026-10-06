class_name RngStreams
extends RefCounted
## Independent, seeded random streams for one run.
##
## Each system draws from its own stream so that, for a given seed, the map is
## the same no matter how many cards were shuffled in combat. This makes seeded
## runs and daily challenges reproducible and makes save/continue deterministic.

const STREAMS: Array[StringName] = [
	&"map", &"encounters", &"rewards", &"shop", &"events", &"combat", &"shuffle", &"misc",
]

var seed_value: int
var _streams: Dictionary = {}  # StringName -> RandomNumberGenerator


func _init(run_seed: int) -> void:
	seed_value = run_seed
	for stream_name in STREAMS:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:%s" % [run_seed, stream_name])
		_streams[stream_name] = rng


func get_stream(stream_name: StringName) -> RandomNumberGenerator:
	assert(_streams.has(stream_name), "Unknown RNG stream: %s" % stream_name)
	return _streams[stream_name]


func shuffle(array: Array, stream_name: StringName = &"shuffle") -> void:
	var rng := get_stream(stream_name)
	for i in range(array.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = array[i]
		array[i] = array[j]
		array[j] = tmp


func pick(array: Array, stream_name: StringName = &"misc"):
	if array.is_empty():
		return null
	return array[get_stream(stream_name).randi_range(0, array.size() - 1)]


## Weighted pick. [param weights] must be parallel to [param items].
func pick_weighted(items: Array, weights: Array, stream_name: StringName = &"misc"):
	if items.is_empty():
		return null
	var total := 0.0
	for w in weights:
		total += float(w)
	var roll := get_stream(stream_name).randf() * total
	for i in items.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			return items[i]
	return items.back()


func to_dict() -> Dictionary:
	var states := {}
	for stream_name in _streams:
		states[String(stream_name)] = str(_streams[stream_name].state)
	return {"seed": seed_value, "states": states}


static func from_dict(data: Dictionary) -> RngStreams:
	var streams := RngStreams.new(int(data.get("seed", 0)))
	var states: Dictionary = data.get("states", {})
	for stream_name in states:
		var key := StringName(stream_name)
		if streams._streams.has(key):
			# States are saved as strings: JSON numbers are doubles and would
			# lose precision on 64-bit values.
			streams._streams[key].state = String(states[stream_name]).to_int()
	return streams
