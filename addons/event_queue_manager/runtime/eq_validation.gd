class_name EQValidation
extends RefCounted
## Result of validating a Resource/API: a list of issues, each tagged from the
## EQError taxonomy with a stable code, severity, and recoverability class.
##
## Validation only reports; it never crashes or skips. A caller in dev mode can
## assert is_valid(), and the resilience toggle (EQM-022) reads each issue's
## recoverability to decide dev-stop vs shipped-degrade.

var issues: Array[Dictionary] = []


## Records an issue for a (known) EQError code. Severity/recoverability are taken
## from the taxonomy so they cannot drift per call-site.
func add(code: StringName, message: String = "", context: Dictionary = {}) -> void:
	issues.append({
		"code": code,
		"severity": EQError.severity_of(code),
		"recoverability": EQError.recoverability_of(code),
		"message": message,
		"context": context,
	})


## Valid iff no ERROR-severity issue is present (WARNINGs do not invalidate).
func is_valid() -> bool:
	for i in issues:
		if int(i["severity"]) == EQError.Severity.ERROR:
			return false
	return true


func errors() -> Array:
	return issues.filter(func(i): return int(i["severity"]) == EQError.Severity.ERROR)


func warnings() -> Array:
	return issues.filter(func(i): return int(i["severity"]) == EQError.Severity.WARNING)


func codes() -> Array:
	return issues.map(func(i): return i["code"])


func has_code(code: StringName) -> bool:
	return codes().has(code)
