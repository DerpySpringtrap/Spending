class_name CombatantView
extends Control
## On-screen combatant: body (placeholder vector art or a real scene) with an
## AnimationPlayer (idle / attack / hurt / cast / victory), HP bar with block,
## status tray and, for enemies, the intent above the head.
##
## Driven only by the combat director's beats, using values from signal
## payloads. It never reads live combat state.

const ENEMY_SIZE := Vector2(250, 400)
const PLAYER_SIZE := Vector2(300, 420)
const DISSOLVE := preload("res://assets/shaders/dissolve.gdshader")

var combatant: Combatant
var is_player := false
var targeted := false:
	set(v):
		if targeted != v:
			targeted = v
			queue_redraw()

var _facing := -1.0
var _feet_y := 0.0
var _art_size := Vector2(180, 200)
var _body_root: Node2D
var _body: Node2D
var _anim: AnimationPlayer
var _intent: IntentView
var _hp: HealthBar
var _tray: StatusTray
var _time := 0.0
var _dead := false
var _aura: Polygon2D


func setup(p_combatant: Combatant) -> CombatantView:
	combatant = p_combatant
	is_player = combatant is PlayerCombatant
	_facing = 1.0 if is_player else -1.0
	return self


func _ready() -> void:
	var view_size := PLAYER_SIZE if is_player else ENEMY_SIZE
	custom_minimum_size = view_size
	size = view_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_feet_y = view_size.y - 92
	_build_body()
	_build_ui()
	_build_animations()
	mouse_entered.connect(func(): EventBus.tooltip_requested.emit(self, combatant.display_name, _description()))
	mouse_exited.connect(func(): EventBus.tooltip_cleared.emit(self))


func _build_body() -> void:
	_body_root = Node2D.new()
	_body_root.name = "BodyRoot"
	_body_root.position = Vector2(size.x / 2, _feet_y)
	add_child(_body_root)
	var scene: PackedScene = null
	var art_id := &""
	var accent := Color("#E8692C")
	if combatant is PlayerCombatant:
		var cls := (combatant as PlayerCombatant).class_data
		scene = cls.combat_scene
		art_id = cls.id
		accent = cls.secondary_color
	elif combatant is EnemyCombatant:
		var data := (combatant as EnemyCombatant).data
		scene = data.visual_scene
		art_id = data.id
	_aura = Polygon2D.new()
	_aura.name = "Aura"
	_aura.polygon = PlaceholderArt.ellipse(Vector2(0, -6), 135, 30)
	_aura.color = Color(1, 1, 1, 0)
	_body_root.add_child(_aura)
	_body = scene.instantiate() if scene else PlaceholderArt.build(art_id, accent)
	_body.name = "Body"
	_body_root.add_child(_body)
	if _body.has_meta("width"):
		_art_size = Vector2(_body.get_meta("width"), _body.get_meta("height"))


func _build_ui() -> void:
	_hp = HealthBar.new()
	_hp.size = Vector2(190, 30)
	_hp.position = Vector2(size.x / 2 - 95, _feet_y + 16)
	add_child(_hp)
	_hp.setup(combatant.hp, combatant.max_hp, combatant.block)
	_tray = StatusTray.new()
	_tray.size = Vector2(240, 40)
	_tray.position = Vector2(size.x / 2 - 120, _feet_y + 50)
	add_child(_tray)
	if not is_player:
		_intent = IntentView.new()
		_intent.position = Vector2(size.x / 2 - IntentView.SIZE.x / 2 + 10, maxf(_feet_y - _art_size.y - 70, 0))
		add_child(_intent)


# --- Animations ---------------------------------------------------------------

func _build_animations() -> void:
	_anim = _body.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if _anim == null:
		_anim = AnimationPlayer.new()
		_anim.name = "AnimationPlayer"
		add_child(_anim)
		var lib := AnimationLibrary.new()
		lib.add_animation(&"idle", _clip_idle())
		lib.add_animation(&"attack", _clip_attack())
		lib.add_animation(&"hurt", _clip_hurt())
		lib.add_animation(&"cast", _clip_cast())
		lib.add_animation(&"victory", _clip_victory())
		_anim.add_animation_library(&"", lib)
	_anim.speed_scale = UIStyle.speed
	if _anim.has_animation(&"idle"):
		_anim.play(&"idle")
		_anim.seek(randf() * 2.0, true)


func _track(anim: Animation, property: String, keys: Array) -> void:
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath("BodyRoot/Body:" + property))
	anim.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	for key in keys:  # [time, value, transition]
		anim.track_insert_key(track, key[0], key[1], key[2] if key.size() > 2 else 1.0)


func _clip_idle() -> Animation:
	var a := Animation.new()
	a.length = 2.4
	a.loop_mode = Animation.LOOP_LINEAR
	_track(a, "scale", [[0.0, Vector2.ONE], [1.2, Vector2(1.015, 0.985)], [2.4, Vector2.ONE]])
	_track(a, "position", [[0.0, Vector2.ZERO], [1.2, Vector2(0, -3)], [2.4, Vector2.ZERO]])
	return a


func _clip_attack() -> Animation:
	var a := Animation.new()
	a.length = 0.42
	_track(a, "position", [[0.0, Vector2.ZERO], [0.06, Vector2(-14 * _facing, 0)], [0.14, Vector2(80 * _facing, -8), 0.3],
		[0.26, Vector2(70 * _facing, -4)], [0.42, Vector2.ZERO]])
	_track(a, "rotation", [[0.0, 0.0], [0.14, 0.12 * _facing], [0.42, 0.0]])
	return a


func _clip_hurt() -> Animation:
	var a := Animation.new()
	a.length = 0.32
	_track(a, "position", [[0.0, Vector2.ZERO], [0.05, Vector2(-26 * _facing, 0)], [0.32, Vector2.ZERO]])
	_track(a, "scale", [[0.0, Vector2.ONE], [0.05, Vector2(0.92, 1.07)], [0.32, Vector2.ONE]])
	return a


func _clip_cast() -> Animation:
	var a := Animation.new()
	a.length = 0.36
	_track(a, "position", [[0.0, Vector2.ZERO], [0.15, Vector2(0, -16)], [0.36, Vector2.ZERO]])
	_track(a, "scale", [[0.0, Vector2.ONE], [0.15, Vector2(1.06, 1.06)], [0.36, Vector2.ONE]])
	return a


func _clip_victory() -> Animation:
	var a := Animation.new()
	a.length = 0.8
	_track(a, "position", [[0.0, Vector2.ZERO], [0.25, Vector2(0, -46), 0.4], [0.5, Vector2.ZERO], [0.62, Vector2(0, -8)], [0.8, Vector2.ZERO]])
	_track(a, "scale", [[0.0, Vector2.ONE], [0.1, Vector2(1.08, 0.92)], [0.25, Vector2(0.95, 1.08)], [0.5, Vector2(1.08, 0.92)], [0.8, Vector2.ONE]])
	return a


func _play(clip: StringName) -> void:
	if _dead or not _anim.has_animation(clip):
		return
	_anim.speed_scale = UIStyle.speed
	_anim.stop()
	_anim.play(clip)
	if _anim.has_animation(&"idle"):
		_anim.queue(&"idle")


func play_attack() -> void:
	_play(&"attack")


func play_hurt() -> void:
	_play(&"hurt")


func play_cast() -> void:
	_play(&"cast")


func play_victory() -> void:
	_play(&"victory")


## Ground glow under the body (Moonblade phases). Alpha 0 hides it.
func set_aura(color: Color) -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(_aura, "color", color, UIStyle.dur(0.3))
	if color.a > 0.0:
		_aura.scale = Vector2(0.6, 0.6)
		t.tween_property(_aura, "scale", Vector2.ONE, UIStyle.dur(0.35)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## White hit flash (overbright modulate).
func flash(color: Color = Color(3, 3, 3)) -> void:
	_body.modulate = color
	create_tween().tween_property(_body, "modulate", Color.WHITE, UIStyle.dur(0.18))


## Dissolve with a glowing edge; UI fades out. The slot stays so the row
## doesn't jump.
func play_death() -> void:
	_dead = true
	_anim.stop()
	var mat := ShaderMaterial.new()
	mat.shader = DISSOLVE
	_body.material = mat
	targeted = false
	var t := create_tween().set_parallel(true)
	t.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.0, 1.0, UIStyle.dur(0.7)).set_ease(Tween.EASE_IN)
	t.tween_property(_body_root, "position:y", _feet_y + 10, UIStyle.dur(0.7))
	for node in [_hp, _tray, _intent]:
		if node:
			t.tween_property(node, "modulate:a", 0.0, UIStyle.dur(0.3))
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# --- State updates (from beats) -----------------------------------------------

func set_hp(hp: int, max_hp: int, animate: bool = true) -> void:
	_hp.set_hp(hp, max_hp, animate)


func set_block(block: int, animate: bool = true) -> void:
	_hp.set_block(block, animate)


func set_status(status: StatusEffectData, stacks: int, pop: bool) -> void:
	_tray.set_status(status, stacks, pop)


func remove_status(status: StatusEffectData) -> void:
	_tray.remove_status(status)


func pulse_status(status_id: StringName) -> void:
	_tray.pulse(status_id)


func set_intent(move: EnemyMoveData, damage: int, hits: int) -> void:
	if _intent and not _dead:
		_intent.set_intent(move, damage, hits)


# --- Queries ------------------------------------------------------------------

func is_dead_shown() -> bool:
	return _dead


func body_rect_global() -> Rect2:
	var local := Rect2(size.x / 2 - _art_size.x / 2, _feet_y - _art_size.y, _art_size.x, _art_size.y)
	return Rect2(global_position + local.position, local.size)


func hit_point() -> Vector2:
	return body_rect_global().get_center()


func head_point() -> Vector2:
	var r := body_rect_global()
	return Vector2(r.get_center().x, r.position.y + 20)


func get_health_bar() -> HealthBar:
	return _hp


func get_status_tray() -> StatusTray:
	return _tray


func get_intent_view() -> IntentView:
	return _intent


func _description() -> String:
	if combatant is EnemyCombatant:
		return (combatant as EnemyCombatant).data.gimmick_text
	if combatant is PlayerCombatant:
		return (combatant as PlayerCombatant).class_data.title
	return ""


# --- Drawing: shadow and target reticle -----------------------------------------

func _process(delta: float) -> void:
	if targeted:
		_time += delta
		queue_redraw()


func _draw() -> void:
	if _dead:
		return
	var feet := Vector2(size.x / 2, _feet_y)
	draw_colored_polygon(PlaceholderArt.ellipse(feet + Vector2(0, 2), _art_size.x * 0.5, 14), Color(0, 0, 0, 0.35))
	if targeted:
		var r := body_rect_global()
		r.position -= global_position
		r = r.grow(14 + sin(_time * 8.0) * 4.0)
		var len := 28.0
		var w := 5.0
		var col := UIStyle.DAMAGE
		for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			var sx := 1.0 if corner.x < r.get_center().x else -1.0
			var sy := 1.0 if corner.y < r.get_center().y else -1.0
			draw_line(corner, corner + Vector2(len * sx, 0), UIStyle.OUTLINE, w + 4)
			draw_line(corner, corner + Vector2(0, len * sy), UIStyle.OUTLINE, w + 4)
			draw_line(corner, corner + Vector2(len * sx, 0), col, w)
			draw_line(corner, corner + Vector2(0, len * sy), col, w)
