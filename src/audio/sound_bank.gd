class_name SoundBank
extends RefCounted
## Sound ids → files. Ids with several variants ("hit") pick one at random so
## repeated sounds don't fatigue. Files would live in assets/audio/.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const AMBIENCE_DIR := "res://assets/audio/ambience/"

## The game is silent for now: the synthesized placeholder sounds were
## removed in test build 5, and real recorded audio is on the roadmap. Every
## call site still asks for its sound by id (AudioManager.play(&"hit")...), so
## adding audio later only means filling these tables (see
## docs/HOOKS_AND_ASSETS.md for the full list of ids).

## id -> list of file base names (variants), e.g. &"hit": ["hit_1", "hit_2"].
const SFX := {}

## Relative loudness per id (dB), so the mix doesn't need tuning at call sites.
const GAIN_DB := {}

## id -> file base name, e.g. &"combat": "combat".
const MUSIC := {}

## id -> file base name, e.g. &"swamp": "swamp".
const AMBIENCE := {}
## Background ambience per act.
const ACT_AMBIENCE := {1: &"swamp", 2: &"crypt", 3: &"observatory", 4: &"void"}

static var _cache: Dictionary = {}


static func sfx(id: StringName) -> AudioStream:
	var variants: Array = SFX.get(id, [])
	if variants.is_empty():
		return null
	return _load(SFX_DIR + String(variants.pick_random()) + ".ogg", false)


static func gain_db(id: StringName) -> float:
	return GAIN_DB.get(id, 0.0)


static func music(id: StringName) -> AudioStream:
	return _load(MUSIC_DIR + String(MUSIC.get(id, "")) + ".ogg", true) if MUSIC.has(id) else null


static func ambience(id: StringName) -> AudioStream:
	return _load(AMBIENCE_DIR + String(AMBIENCE.get(id, "")) + ".ogg", true) if AMBIENCE.has(id) else null


static func _load(path: String, looping: bool) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		push_warning("SoundBank: missing %s" % path)
		_cache[path] = null
		return null
	var stream: AudioStream = load(path)
	if looping and stream is AudioStreamOggVorbis:
		stream.loop = true
	_cache[path] = stream
	return stream


static func clear_cache() -> void:
	_cache.clear()
