extends CanvasLayer
## Screen transitions (autoload: SceneRouter).
##
## All screen changes go through [method go_to] so every transition gets the
## same polished fade, input is blocked mid-transition, and EventBus.screen_changed
## fires for music/ambience switching. Slide/scale-in variants arrive with the
## Milestone 2 UI pass; the fade is the baseline.

signal transition_finished

const FADE_TIME := 0.35

var is_transitioning := false
var _overlay: ColorRect
var _target := ""
## A different screen requested mid-transition (co-op: the party moved on
## while this client was still fading). Visited as soon as the fade ends.
var _queued: Array = []


func _ready() -> void:
	UIStyle.install_font_fallbacks()
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = ColorRect.new()
	_overlay.color = Color(0.03, 0.02, 0.05, 0.0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


func go_to(scene_path: String, screen_id: StringName = &"") -> void:
	if is_transitioning:
		if scene_path != _target:
			_queued = [scene_path, screen_id]
		return
	is_transitioning = true
	_target = scene_path
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0)
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneRouter: failed to load %s (%s)" % [scene_path, error_string(err)])
	# Wait one frame so the new scene's _ready runs while the screen is black.
	await get_tree().process_frame
	EventBus.screen_changed.emit(screen_id if screen_id != &"" else StringName(scene_path.get_file().get_basename()))
	await _fade_to(0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false
	_target = ""
	transition_finished.emit()
	if not _queued.is_empty():
		var next: Array = _queued
		_queued = []
		go_to(next[0], next[1])


func _fade_to(alpha: float) -> void:
	var duration := FADE_TIME * (0.5 if Settings.fast_mode else 1.0)
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", alpha, duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
