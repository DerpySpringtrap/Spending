class_name PresentationQueue
extends Node
## Plays combat "beats" in order so the player can follow what happened.
##
## Combat logic resolves instantly; the director (combat screen) converts each
## EventBus signal into a beat: a callable that *starts* animations (tweens,
## AnimationPlayer clips, particles, sounds) plus how long to wait before the
## next beat. Beats never change game state.
##
## Grouping: consecutive beats with the same non-empty group key run in
## parallel as long as they affect different targets. So an AoE hit on three
## enemies plays at once, while a 4-hit attack on one enemy plays hit by hit.
## The group waits for its longest member.
##
## Durations scale with UIStyle.speed (fast mode, tests). Waits respect
## Engine.time_scale, so hit-stop also pauses the queue.

signal idle

const INSTANT := &"instant"

var _groups: Array[Dictionary] = []  # {key, targets: Array, actions: Array[Callable], duration}
var _running := false


func is_busy() -> bool:
	return _running or not _groups.is_empty()


## Adds a beat. [param target] identifies what it affects (combatant or card id)
## for grouping; [param action] may take one int argument (its index within the
## group) to stagger parallel animations.
func push(key: StringName, target: int, duration: float, action: Callable) -> void:
	var last: Dictionary = _groups.back() if not _groups.is_empty() else {}
	var joinable: bool = not last.is_empty() and key != &"" and last.key == key \
			and (key == INSTANT or not last.targets.has(target))
	if joinable:
		last.targets.append(target)
		last.actions.append(action)
		last.duration = maxf(last.duration, duration)
	else:
		_groups.append({"key": key, "targets": [target], "actions": [action], "duration": duration})
	if not _running:
		_running = true
		_run.call_deferred()


## Drops pending beats (leaving the screen).
func clear() -> void:
	_groups.clear()


func _run() -> void:
	while not _groups.is_empty():
		var group: Dictionary = _groups.pop_front()
		var actions: Array = group.actions
		for i in actions.size():
			var action: Callable = actions[i]
			if action.get_argument_count() >= 1:
				action.call(i)
			else:
				action.call()
		var wait := UIStyle.dur(group.duration)
		if wait > 0.0 and is_inside_tree():
			await get_tree().create_timer(wait, false).timeout
		if not is_inside_tree():
			break
	_running = false
	idle.emit()
