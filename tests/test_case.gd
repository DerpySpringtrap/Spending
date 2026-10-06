class_name TestCase
extends RefCounted
## Minimal xUnit-style base class. Methods starting with "test_" are run by
## tests/test_runner.tscn; each gets a fresh instance.

var failures: PackedStringArray = []
var _current_test := ""


func before_each() -> void:
	pass


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append("%s: %s" % [_current_test, message])


func check_eq(actual, expected, message: String) -> void:
	if actual != expected:
		failures.append("%s: %s (expected %s, got %s)" % [_current_test, message, str(expected), str(actual)])
