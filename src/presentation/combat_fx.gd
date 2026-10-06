class_name CombatFX
extends Control
## Screen-space effects layer: damage numbers, particle bursts, screen shake
## and hit-stop. Lives above the world and HUD with mouse input ignored.

## The node screen shake moves (the combat World), set by the combat screen.
var shake_target: Control

var _shake_strength := 0.0
var _shake_origin := Vector2.ZERO
var _hit_stop_until := 0
static var _dot_texture: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if shake_target == null:
		return
	if _shake_strength > 0.05:
		shake_target.position = _shake_origin + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
		_shake_strength = lerpf(_shake_strength, 0.0, 1.0 - exp(-delta * 14.0))
	elif _shake_strength > 0.0:
		_shake_strength = 0.0
		shake_target.position = _shake_origin


func _exit_tree() -> void:
	Engine.time_scale = 1.0


## Shake scaled by the player's setting. 4 = light tap, 18 = huge hit.
func shake(strength: float) -> void:
	if shake_target == null:
		return
	if _shake_strength <= 0.0:
		_shake_origin = shake_target.position
	_shake_strength = maxf(_shake_strength, strength * Settings.screen_shake)


## Brief freeze-frame on impact. Skipped in fast mode.
func hit_stop(duration: float = 0.07) -> void:
	if UIStyle.speed > 1.5:
		return
	Engine.time_scale = 0.05
	var until := Time.get_ticks_msec() + int(duration * 1000.0)
	_hit_stop_until = maxi(_hit_stop_until, until)
	await get_tree().create_timer(duration, true, false, true).timeout
	if Time.get_ticks_msec() >= _hit_stop_until:
		Engine.time_scale = 1.0


## Pop-up number: scales in with overshoot, drifts up and fades.
func number(global_pos: Vector2, text: String, color: Color, big: bool = false) -> void:
	if not Settings.show_damage_numbers:
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UIStyle.display_font())
	label.add_theme_font_size_override("font_size", 52 if big else 38)
	label.add_theme_color_override("font_color", color)
	UIStyle.outline_label(label, 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.reset_size()
	label.pivot_offset = label.size / 2
	var start := global_pos - get_global_rect().position - label.size / 2 + Vector2(randf_range(-24, 24), 0)
	label.position = start
	label.scale = Vector2(0.3, 0.3)
	var t := label.create_tween().set_parallel(true)
	t.tween_property(label, "scale", Vector2.ONE * (1.25 if big else 1.0), UIStyle.dur(0.18)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "position:y", start.y - 90, UIStyle.dur(0.8)) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "modulate:a", 0.0, UIStyle.dur(0.3)).set_delay(UIStyle.dur(0.55))
	t.chain().tween_callback(label.queue_free)


## One-shot particle burst. [param gravity] > 0 falls (drips), < 0 rises (flames).
func burst(global_pos: Vector2, color: Color, amount: int = 16, speed: float = 260.0,
		gravity: float = 500.0, spread: float = 180.0, size: float = 1.0, direction: Vector2 = Vector2.UP) -> void:
	var p := GPUParticles2D.new()
	p.one_shot = true
	p.amount = maxi(amount, 1)
	p.lifetime = 0.7
	p.explosiveness = 0.95
	p.local_coords = false
	p.texture = _dot()
	var m := ParticleProcessMaterial.new()
	m.particle_flag_disable_z = true
	m.direction = Vector3(direction.x, direction.y, 0)
	m.spread = spread
	m.initial_velocity_min = speed * 0.4
	m.initial_velocity_max = speed
	m.gravity = Vector3(0, gravity, 0)
	m.damping_min = 40.0
	m.damping_max = 80.0
	m.scale_min = 0.35 * size
	m.scale_max = 0.8 * size
	m.color = color
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	m.color_ramp = ramp
	p.process_material = m
	add_child(p)
	p.global_position = global_pos
	p.emitting = true
	p.finished.connect(p.queue_free)
	# Safety net in case "finished" never fires (headless renderer).
	get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(p): p.queue_free())


static func _dot() -> Texture2D:
	if _dot_texture == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.55, Color(1, 1, 1, 0.9))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 24
		tex.height = 24
		_dot_texture = tex
	return _dot_texture
