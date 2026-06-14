extends RefCounted
## Minimal assertion collector for headless suites.
## Loaded by path (not class_name) so it never depends on global class
## registration in a fresh headless project.

var failures: Array[String] = []
var checks: int = 0


func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)


func eq(actual, expected, msg: String) -> void:
	checks += 1
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [msg, str(expected), str(actual)])
