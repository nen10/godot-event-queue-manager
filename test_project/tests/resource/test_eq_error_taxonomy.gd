extends RefCounted
## EQM-020: error taxonomy — stable codes map to fixed recoverability/severity/
## surfacing, and EQValidation aggregates issues correctly.

const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")
const EQValidation := preload("res://addons/event_queue_manager/runtime/eq_validation.gd")


static func run(t) -> void:
	_test_code_metadata(t)
	_test_unknown_code_strict_default(t)
	_test_validation_aggregation(t)


static func _test_code_metadata(t) -> void:
	# recoverability classes mirror RUNTIME_RESILIENCE_POLICY §1
	t.eq(EQError.recoverability_of(EQError.POLICY_MISSING), EQError.Recoverability.RESOURCE_INVALID, "policy_missing = RESOURCE_INVALID")
	t.eq(EQError.recoverability_of(EQError.POLICY_BASE_INSTANCE), EQError.Recoverability.CONTRACT_VIOLATION, "base_instance = CONTRACT_VIOLATION")
	t.eq(EQError.recoverability_of(EQError.TIE_BREAK_AMBIGUOUS), EQError.Recoverability.RESOURCE_INVALID, "tie_break_ambiguous = RESOURCE_INVALID")
	t.eq(EQError.recoverability_of(EQError.TIE_BREAK_UNKNOWN), EQError.Recoverability.CONTRACT_VIOLATION, "tie_break_unknown = CONTRACT_VIOLATION")
	# severity
	t.eq(EQError.severity_of(EQError.POLICY_MISSING), EQError.Severity.ERROR, "policy_missing is ERROR")
	t.eq(EQError.severity_of(EQError.POLICY_NAME_EMPTY), EQError.Severity.WARNING, "policy_name_empty is WARNING")
	# surfacing
	t.ok(EQError.surfaces_in(EQError.POLICY_MISSING, "game"), "policy_missing surfaces in game")
	t.ok(EQError.surfaces_in(EQError.POLICY_MISSING, "editor"), "policy_missing surfaces in editor")
	t.ok(EQError.surfaces_in(EQError.POLICY_NAME_EMPTY, "editor"), "name_empty surfaces in editor")
	t.ok(not EQError.surfaces_in(EQError.POLICY_NAME_EMPTY, "game"), "name_empty does not surface in game")
	# code stability: codes are namespaced strings
	t.eq(String(EQError.POLICY_MISSING), "eqm.config.policy_missing", "code is the stable namespaced string")
	t.ok(EQError.is_known(EQError.TIE_BREAK_UNKNOWN), "known code recognised")


static func _test_unknown_code_strict_default(t) -> void:
	var bogus := &"eqm.does.not.exist"
	t.ok(not EQError.is_known(bogus), "unknown code not known")
	t.eq(EQError.recoverability_of(bogus), EQError.Recoverability.CONTRACT_VIOLATION, "unknown code defaults to strictest recoverability")
	t.eq(EQError.severity_of(bogus), EQError.Severity.ERROR, "unknown code defaults to ERROR (never silently downgraded)")
	t.ok(EQError.surfaces_in(bogus, "game"), "unknown code surfaces rather than hides")


static func _test_validation_aggregation(t) -> void:
	var v := EQValidation.new()
	t.ok(v.is_valid(), "empty validation is valid")
	v.add(EQError.POLICY_NAME_EMPTY, "hint")
	t.ok(v.is_valid(), "a WARNING alone keeps it valid")
	t.eq(v.warnings().size(), 1, "warning counted")
	v.add(EQError.POLICY_MISSING, "no policy")
	t.ok(not v.is_valid(), "an ERROR invalidates")
	t.eq(v.errors().size(), 1, "one error")
	t.ok(v.has_code(EQError.POLICY_MISSING), "has_code finds the error")
	t.eq(v.codes().size(), 2, "codes lists all issues")
	# each issue carries its taxonomy tags
	var err = v.errors()[0]
	t.eq(err["recoverability"], EQError.Recoverability.RESOURCE_INVALID, "issue carries recoverability from taxonomy")
