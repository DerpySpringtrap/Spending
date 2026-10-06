extends Node
## Player settings (autoload: Settings). Stored separately from saves in
## user://settings.cfg so wiping progress never resets audio/video options.

signal changed(key: StringName)

const PATH := "user://settings.cfg"
const AUDIO_BUSES: Array[StringName] = [&"Master", &"Music", &"SFX", &"UI", &"Ambience"]

var volumes: Dictionary = {
	&"Master": 0.8, &"Music": 0.7, &"SFX": 0.8, &"UI": 0.8, &"Ambience": 0.6,
}
var screen_shake: float = 1.0       ## 0 = off. Scales every shake request.
var fast_mode: bool = false         ## Shortens presentation beats.
var fullscreen: bool = false
var ui_scale: float = 1.0
var show_damage_numbers: bool = true


func _ready() -> void:
	load_settings()
	apply_all()


func set_volume(bus: StringName, linear: float) -> void:
	volumes[bus] = clampf(linear, 0.0, 1.0)
	_apply_volume(bus)
	changed.emit(bus)


func apply_all() -> void:
	for bus in AUDIO_BUSES:
		_apply_volume(bus)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(mode)
	get_tree().root.content_scale_factor = ui_scale


func _apply_volume(bus: StringName) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		return
	var linear: float = volumes.get(bus, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(index, linear <= 0.001)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for bus in volumes:
		cfg.set_value("audio", String(bus), volumes[bus])
	cfg.set_value("gameplay", "screen_shake", screen_shake)
	cfg.set_value("gameplay", "fast_mode", fast_mode)
	cfg.set_value("gameplay", "show_damage_numbers", show_damage_numbers)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "ui_scale", ui_scale)
	cfg.save(PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for bus in AUDIO_BUSES:
		volumes[bus] = cfg.get_value("audio", String(bus), volumes.get(bus, 1.0))
	screen_shake = cfg.get_value("gameplay", "screen_shake", screen_shake)
	fast_mode = cfg.get_value("gameplay", "fast_mode", fast_mode)
	show_damage_numbers = cfg.get_value("gameplay", "show_damage_numbers", show_damage_numbers)
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	ui_scale = cfg.get_value("video", "ui_scale", ui_scale)
