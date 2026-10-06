class_name StatusTray
extends HFlowContainer
## Row of StatusIcons, kept in application order.

var _icons: Dictionary = {}  # status id -> StatusIcon


func _init() -> void:
	add_theme_constant_override("h_separation", 4)
	add_theme_constant_override("v_separation", 4)
	alignment = FlowContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_status(status: StatusEffectData, stacks: int, pop: bool) -> void:
	if status.hidden:
		return
	var icon: StatusIcon = _icons.get(status.id)
	if icon == null:
		icon = StatusIcon.new()
		icon.status = status
		_icons[status.id] = icon
		add_child(icon)
		icon.scale = Vector2(0.2, 0.2)
		pop = true
	icon.set_stacks(stacks, pop)


func remove_status(status: StatusEffectData) -> void:
	var icon: StatusIcon = _icons.get(status.id)
	if icon == null:
		return
	_icons.erase(status.id)
	EventBus.tooltip_cleared.emit(icon)
	var t := icon.create_tween()
	t.tween_property(icon, "modulate:a", 0.0, UIStyle.dur(0.15))
	t.tween_callback(icon.queue_free)


func pulse(status_id: StringName) -> void:
	var icon: StatusIcon = _icons.get(status_id)
	if icon:
		icon.pulse()


## {status id: stacks} as currently displayed (consistency tests).
func get_shown() -> Dictionary:
	var out := {}
	for id in _icons:
		out[id] = _icons[id].stacks
	return out
