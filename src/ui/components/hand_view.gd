class_name HandView
extends Control
## The hand: fan layout, hover/focus lift, drag-to-play and keyboard targeting.
##
## Knows nothing about combat rules. It asks [member can_pick_up] whether a
## card may be lifted and [member target_at] what's under the cursor, and
## reports intent through signals. The combat screen decides whether a play is
## legal and calls CombatState.

signal play_requested(card: CardInstance, target: Combatant)
## During a drag: the enemy under the arrow (single-target) or whether an
## untargeted card is past the play line ("armed").
signal target_changed(card: CardInstance, target: Combatant, armed: bool)
signal drag_cancelled(card: CardInstance)
signal rejected(card: CardInstance, reason: String)

const MAX_SPREAD := 150.0
const FAN_ANGLE := 3.0
const ARC_DROP := 6.0
const HOVER_SCALE := 1.28
const READY_SCALE := 1.12
const NEIGHBOUR_PUSH := 80.0
const BASE_SINK := 4.0

## Callable(card: CardInstance) -> String. Empty string = may be picked up.
var can_pick_up: Callable
## Callable(global_pos: Vector2) -> Combatant (living enemy under the point) or null.
var target_at: Callable
var arrow: TargetingArrow
## Fraction of the viewport height above which a dragged untargeted card is armed.
var play_line_ratio := 0.6

var _views: Array[CardView] = []
var _hovered: CardView
var _focus_index := -1
var _keyboard_active := false
var _dragging: CardView
var _drag_offset := Vector2.ZERO
var _drag_target: Combatant
var _drag_armed := false
var _kb_targeting: CardView
var _pending: Dictionary = {}   # CardView -> true: released for play, awaiting its beat
var _tweens: Dictionary = {}    # CardView -> Tween
var _fresh: Dictionary = {}     # CardView -> true: just drawn, flies in on an arc


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(relayout)


# =============================================================================
# Cards in / out
# =============================================================================

func get_views() -> Array[CardView]:
	return _views


func view_for(card: CardInstance) -> CardView:
	for view in _views:
		if view.card == card:
			return view
	return null


## Adds a card view, flying it in along an arc from [param from_global].
func add_card(view: CardView, from_global: Vector2) -> void:
	if view.get_parent():
		view.reparent(self, true)
	else:
		add_child(view)
	view.global_position = from_global - view.pivot_offset + Vector2(0, CardView.SIZE.y * 0.15)
	view.scale = Vector2(0.3, 0.3)
	view.rotation = 0.0
	_views.append(view)
	_fresh[view] = true
	view.hovered.connect(_on_hovered)
	view.unhovered.connect(_on_unhovered)
	view.pressed.connect(_on_pressed)
	relayout(true)


## Removes a card from the hand and hands its view to the caller (who
## reparents and animates it). Returns null if the card has no view.
func take_card(card: CardInstance) -> CardView:
	var view := view_for(card)
	if view == null:
		return null
	_views.erase(view)
	_pending.erase(view)
	_fresh.erase(view)
	_kill_tween(view)
	view.hovered.disconnect(_on_hovered)
	view.unhovered.disconnect(_on_unhovered)
	view.pressed.disconnect(_on_pressed)
	view.glowing = false
	view.selected = false
	if _hovered == view:
		_hovered = null
		EventBus.tooltip_cleared.emit(view)
	if _dragging == view:
		_dragging = null
	if _kb_targeting == view:
		_kb_targeting = null
	_focus_index = clampi(_focus_index, -1, _views.size() - 1)
	relayout()
	return view


## A play was refused by the rules: put the card back.
func return_card(card: CardInstance) -> void:
	var view := view_for(card)
	if view:
		_pending.erase(view)
		view.glowing = false
		view.selected = false
		_shake(view)
	relayout()


# =============================================================================
# Layout
# =============================================================================

func _highlight_index() -> int:
	if _dragging != null or _kb_targeting != null:
		return -1
	if _hovered != null:
		return _views.find(_hovered)
	return _focus_index if _keyboard_active else -1


func relayout(_animate: bool = true) -> void:
	var n := _views.size()
	if n == 0:
		return
	var highlight := _highlight_index()
	var spread := minf(MAX_SPREAD, size.x * 0.55 / maxf(n - 1, 1))
	for i in n:
		var view := _views[i]
		if view == _dragging or view == _kb_targeting or _pending.has(view):
			continue
		var offset := i - (n - 1) / 2.0
		var pivot := Vector2(size.x / 2 + offset * spread, size.y + BASE_SINK + ARC_DROP * offset * offset)
		var rot := deg_to_rad(offset * FAN_ANGLE)
		var scl := 1.0
		view.z_index = i
		if highlight >= 0:
			if i == highlight:
				pivot.y = size.y - 6
				rot = 0.0
				scl = HOVER_SCALE
				view.z_index = 50
			else:
				var d := i - highlight
				pivot.x += signf(d) * NEIGHBOUR_PUSH / maxf(absf(d), 1.0)
		if _fresh.has(view):
			_fresh.erase(view)
			_tween_to(view, pivot, rot, scl, 0.32, 180.0)
		else:
			_tween_to(view, pivot, rot, scl, UIStyle.DUR_BASE)


func _ready_pivot() -> Vector2:
	return Vector2(size.x / 2, size.y - 20)


func _tween_to(view: CardView, pivot: Vector2, rot: float, scl: float, duration: float, arc: float = 0.0) -> void:
	_kill_tween(view)
	var target_pos := pivot - view.pivot_offset
	var t := view.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if arc > 0.0:
		var start := view.position
		var control := (start + target_pos) / 2 + Vector2(0, -arc)
		t.tween_method(func(k: float): view.position = start.lerp(control, k).lerp(control.lerp(target_pos, k), k),
				0.0, 1.0, UIStyle.dur(duration))
	else:
		t.tween_property(view, "position", target_pos, UIStyle.dur(duration))
	t.tween_property(view, "rotation", rot, UIStyle.dur(duration))
	t.tween_property(view, "scale", Vector2(scl, scl), UIStyle.dur(duration))
	_tweens[view] = t


func _kill_tween(view: CardView) -> void:
	var t: Tween = _tweens.get(view)
	if t and t.is_valid():
		t.kill()
	_tweens.erase(view)


func _shake(view: CardView) -> void:
	var t := view.create_tween()
	var base_rot := view.rotation
	for i in 4:
		t.tween_property(view, "rotation", base_rot + (0.06 if i % 2 == 0 else -0.06), UIStyle.dur(0.04))
	t.tween_property(view, "rotation", base_rot, UIStyle.dur(0.04))


# =============================================================================
# Mouse: hover & drag
# =============================================================================

func _on_hovered(view: CardView) -> void:
	if _dragging != null or _kb_targeting != null or _pending.has(view):
		return
	_keyboard_active = false
	_hovered = view
	_focus_index = _views.find(view)
	EventBus.tooltip_requested.emit(view, "", CardTooltips.for_card(view.card))
	relayout()


func _on_unhovered(view: CardView) -> void:
	if _hovered == view:
		_hovered = null
		EventBus.tooltip_cleared.emit(view)
		relayout()


func _on_pressed(view: CardView, event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT or _dragging != null or _kb_targeting != null or _pending.has(view):
		return
	var reason: String = can_pick_up.call(view.card) if can_pick_up.is_valid() else ""
	if reason != "":
		rejected.emit(view.card, reason)
		_shake(view)
		return
	_begin_drag(view, event.global_position)


func _begin_drag(view: CardView, mouse: Vector2) -> void:
	_dragging = view
	_hovered = null
	EventBus.tooltip_cleared.emit(view)
	_drag_target = null
	_drag_armed = false
	view.z_index = 100
	view.selected = true
	if _is_targeted(view):
		_tween_to(view, _ready_pivot(), 0.0, READY_SCALE, UIStyle.DUR_FAST)
		_update_drag(mouse)
	else:
		_kill_tween(view)
		view.rotation = 0.0
		view.scale = Vector2(READY_SCALE, READY_SCALE)
		_drag_offset = view.global_position - mouse
	relayout()


func _input(event: InputEvent) -> void:
	if _dragging == null:
		return
	if event is InputEventMouseMotion:
		_update_drag(event.global_position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_release_drag(event.global_position)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_drag()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_cancel_drag()
		get_viewport().set_input_as_handled()


func _update_drag(mouse: Vector2) -> void:
	var view := _dragging
	if _is_targeted(view):
		var target: Combatant = target_at.call(mouse) if target_at.is_valid() else null
		if arrow:
			arrow.show_between(_arrow_origin(view), mouse, target != null)
		if target != _drag_target:
			_drag_target = target
			target_changed.emit(view.card, target, target != null)
	else:
		view.global_position = mouse + _drag_offset
		var armed := mouse.y < get_viewport_rect().size.y * play_line_ratio
		if armed != _drag_armed:
			_drag_armed = armed
			view.glowing = armed
			target_changed.emit(view.card, null, armed)


func _release_drag(mouse: Vector2) -> void:
	var view := _dragging
	if _is_targeted(view):
		var target: Combatant = target_at.call(mouse) if target_at.is_valid() else null
		if target != null:
			_finish_play(view, target)
			return
	elif _drag_armed:
		_finish_play(view, null)
		return
	_cancel_drag()


func _finish_play(view: CardView, target: Combatant) -> void:
	_dragging = null
	if arrow:
		arrow.hide_arrow()
	_pending[view] = true
	view.selected = false
	play_requested.emit(view.card, target)


func _cancel_drag() -> void:
	var view := _dragging
	_dragging = null
	if arrow:
		arrow.hide_arrow()
	if view:
		view.glowing = false
		view.selected = false
		target_changed.emit(view.card, null, false)
		drag_cancelled.emit(view.card)
	relayout()


func is_dragging() -> bool:
	return _dragging != null


# =============================================================================
# Keyboard / gamepad
# =============================================================================

func move_focus(delta: int) -> void:
	if _views.is_empty():
		return
	_keyboard_active = true
	_hovered = null
	if _focus_index < 0:
		_focus_index = 0 if delta > 0 else _views.size() - 1
	else:
		_focus_index = wrapi(_focus_index + delta, 0, _views.size())
	_announce_focus()
	relayout()


func set_focus(index: int) -> void:
	if index < 0 or index >= _views.size():
		return
	_keyboard_active = true
	_hovered = null
	_focus_index = index
	_announce_focus()
	relayout()


func focused_card() -> CardInstance:
	if _focus_index >= 0 and _focus_index < _views.size():
		return _views[_focus_index].card
	return null


func _announce_focus() -> void:
	var view := _views[_focus_index]
	EventBus.tooltip_requested.emit(view, "", CardTooltips.for_card(view.card))


func begin_keyboard_targeting(card: CardInstance) -> void:
	var view := view_for(card)
	if view == null:
		return
	EventBus.tooltip_cleared.emit(view)
	_kb_targeting = view
	view.selected = true
	view.z_index = 100
	_tween_to(view, _ready_pivot(), 0.0, READY_SCALE, UIStyle.DUR_FAST)
	relayout()


func point_keyboard_arrow(global_target: Vector2) -> void:
	if _kb_targeting and arrow:
		arrow.show_between(_arrow_origin(_kb_targeting), global_target, true)


func end_keyboard_targeting(played: bool) -> void:
	var view := _kb_targeting
	_kb_targeting = null
	if arrow:
		arrow.hide_arrow()
	if view:
		view.selected = false
		if played:
			_pending[view] = true
	relayout()


# =============================================================================
# Helpers
# =============================================================================

func _is_targeted(view: CardView) -> bool:
	return view.card.data.target_mode == CardData.TargetMode.SINGLE_ENEMY


## Where the arrow starts: the top centre of the card at its ready position.
func _arrow_origin(view: CardView) -> Vector2:
	return global_position + _ready_pivot() - Vector2(0, CardView.SIZE.y * READY_SCALE)

