class_name ActionQueue
extends RefCounted
## FIFO of pending reactions (status/relic triggers).
##
## Card and move effects resolve immediately in order; anything they *cause*
## ("when attacked", "when an enemy dies") is queued and resolved afterwards.
## This gives trigger chains a predictable order and avoids deep recursion.

## Guards against infinite trigger loops in bad content.
const MAX_ACTIONS_PER_FLUSH := 5000

var _queue: Array[Callable] = []
var _flushing := false


func push(action: Callable) -> void:
	_queue.append(action)


func is_empty() -> bool:
	return _queue.is_empty()


func clear() -> void:
	_queue.clear()


## Runs actions until the queue is empty or [param should_stop] returns true.
## Re-entrant calls are ignored: the outer flush drains anything queued.
func flush(should_stop: Callable) -> void:
	if _flushing:
		return
	_flushing = true
	var count := 0
	while not _queue.is_empty():
		if should_stop.call():
			_queue.clear()
			break
		var action: Callable = _queue.pop_front()
		action.call()
		count += 1
		if count >= MAX_ACTIONS_PER_FLUSH:
			push_error("ActionQueue: %d actions in one flush; likely an infinite trigger loop" % count)
			_queue.clear()
			break
	_flushing = false
