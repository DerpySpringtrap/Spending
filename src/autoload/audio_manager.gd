extends Node
## Music, ambience and SFX playback (autoload: AudioManager).
##
## Music uses two players that crossfade, so switching map -> combat -> boss
## never hard-cuts. SFX use a small voice pool with slight pitch randomisation
## to avoid repetition fatigue. Sounds are addressed by id through SoundBank
## (play(&"hit")). Screen music/ambience follows EventBus.screen_changed, and
## every Button in the game gets hover/click sounds automatically.

const SFX_VOICES := 16
const DEFAULT_FADE := 1.5

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keep music going while paused.
	_music_a = _make_player(&"Music")
	_music_b = _make_player(&"Music")
	_active_music = _music_a
	_ambience = _make_player(&"Ambience")
	for i in SFX_VOICES:
		_sfx_pool.append(_make_player(&"SFX"))
	EventBus.screen_changed.connect(_on_screen_changed)
	get_tree().node_added.connect(_on_node_added)


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus if AudioServer.get_bus_index(bus) != -1 else &"Master"
	add_child(player)
	return player


## Crossfades to [param stream]. Same stream = no-op, so screens can call this
## freely on enter.
func play_music(stream: AudioStream, fade_time: float = DEFAULT_FADE) -> void:
	if stream != null and _active_music.stream == stream and _active_music.playing:
		return
	var outgoing := _active_music
	var incoming := _music_b if _active_music == _music_a else _music_a
	_active_music = incoming
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	if stream:
		incoming.stream = stream
		incoming.volume_db = -60.0
		incoming.play()
		_music_tween.tween_property(incoming, "volume_db", 0.0, fade_time) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if outgoing.playing:
		_music_tween.tween_property(outgoing, "volume_db", -60.0, fade_time) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_music_tween.chain().tween_callback(outgoing.stop)


func stop_music(fade_time: float = DEFAULT_FADE) -> void:
	play_music(null, fade_time)


func play_ambience(stream: AudioStream, fade_time: float = 2.0) -> void:
	if _ambience.stream == stream and _ambience.playing:
		return
	var tween := create_tween()
	if _ambience.playing:
		tween.tween_property(_ambience, "volume_db", -60.0, fade_time * 0.5)
	tween.tween_callback(func():
		_ambience.stream = stream
		if stream:
			_ambience.volume_db = -60.0
			_ambience.play()
	)
	if stream:
		tween.tween_property(_ambience, "volume_db", -6.0, fade_time * 0.5)


## Plays a one-shot. [param pitch_variance] of 0.05 = +/-5% pitch.
func play_sfx(stream: AudioStream, pitch_variance: float = 0.05, volume_db: float = 0.0, bus: StringName = &"SFX") -> void:
	if stream == null:
		return
	var player := _sfx_pool[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx_pool.size()
	player.stream = stream
	player.bus = bus if AudioServer.get_bus_index(bus) != -1 else &"Master"
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	player.play()


func play_ui(stream: AudioStream) -> void:
	play_sfx(stream, 0.03, 0.0, &"UI")


## Picks one stream at random from a list (varied impact sounds).
func play_random_sfx(streams: Array[AudioStream], pitch_variance: float = 0.05) -> void:
	if not streams.is_empty():
		play_sfx(streams.pick_random(), pitch_variance)


# --- Id-based API (SoundBank) -----------------------------------------------------

## Plays a sound effect by id with the bank's gain and slight pitch variance.
func play(id: StringName, pitch_variance: float = 0.05, volume_db: float = 0.0) -> void:
	play_sfx(SoundBank.sfx(id), pitch_variance, SoundBank.gain_db(id) + volume_db)


func play_ui_id(id: StringName) -> void:
	play_sfx(SoundBank.sfx(id), 0.03, SoundBank.gain_db(id), &"UI")


func play_music_id(id: StringName, fade_time: float = DEFAULT_FADE) -> void:
	play_music(SoundBank.music(id), fade_time)


func play_ambience_id(id: StringName) -> void:
	play_ambience(SoundBank.ambience(id))


## Music and ambience per screen. Combat picks its own track (normal, elite,
## boss) because only it knows the encounter.
func _on_screen_changed(screen_id: StringName) -> void:
	var act := RunState.act if RunState.active else 1
	match screen_id:
		&"main_menu", &"class_select":
			play_music_id(&"menu")
			play_ambience(null)
		&"map", &"reward", &"shop", &"rest", &"event":
			play_music_id(&"map_act%d" % act)
			play_ambience_id(&"swamp" if act == 1 else &"crypt")
		&"run_summary":
			stop_music(0.8)
			play_ambience(null)
			var victory: bool = GameManager.last_run_summary.get("victory", false)
			play(&"victory" if victory else &"defeat", 0.0)


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node is PileButton:
		node.mouse_entered.connect(func(): if not node.disabled: play_ui_id(&"ui_hover"))
		node.pressed.connect(func(): play_ui_id(&"ui_click"))
