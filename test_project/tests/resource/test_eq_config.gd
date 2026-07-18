extends RefCounted
## EQM-020: EQConfig validation (missing/base/ambiguous/unknown/valid) and .tres
## roundtrip. Rejection tests guard the narrowed policy slot and tie_break set
## (UX_PATH_REDUCTION) so a silent default can never quietly reappear.

const EQConfig := preload("res://addons/event_queue_manager/resources/eq_config.gd")
const EQPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_policy.gd")
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")


## A concrete policy subclass stands in for a Phase 3 policy (the slot accepts
## exactly a concrete EQPolicy subclass, not the base).
class StubPolicy extends EQPolicy:
	pass


static func run(t) -> void:
	_test_valid_config(t)
	_test_missing_policy(t)
	_test_base_instance_rejected(t)
	_test_tie_break_ambiguous(t)
	_test_tie_break_unknown(t)
	_test_scheduler_backend_values(t)
	_test_tres_roundtrip(t)


static func _test_valid_config(t) -> void:
	var cfg := EQConfig.new()
	cfg.policy = StubPolicy.new()
	cfg.tie_break = &"sequence"
	var v := cfg.validate()
	t.ok(v.is_valid(), "concrete policy + known tie_break is valid")
	t.eq(v.issues.size(), 0, "valid config reports no issues (no false errors)")


static func _test_missing_policy(t) -> void:
	var cfg := EQConfig.new()  # policy defaults to null
	var v := cfg.validate()
	t.ok(not v.is_valid(), "missing policy is invalid")
	t.ok(v.has_code(EQError.POLICY_MISSING), "missing policy -> POLICY_MISSING")


static func _test_base_instance_rejected(t) -> void:
	var cfg := EQConfig.new()
	cfg.policy = EQPolicy.new()  # raw base instance
	var v := cfg.validate()
	t.ok(not v.is_valid(), "raw base policy is invalid")
	t.ok(v.has_code(EQError.POLICY_BASE_INSTANCE), "base instance -> POLICY_BASE_INSTANCE")


static func _test_tie_break_ambiguous(t) -> void:
	var cfg := EQConfig.new()
	cfg.policy = StubPolicy.new()
	cfg.tie_break = &""
	var v := cfg.validate()
	t.ok(not v.is_valid(), "unset tie_break is invalid")
	t.ok(v.has_code(EQError.TIE_BREAK_AMBIGUOUS), "unset tie_break -> TIE_BREAK_AMBIGUOUS")


static func _test_tie_break_unknown(t) -> void:
	var cfg := EQConfig.new()
	cfg.policy = StubPolicy.new()
	cfg.tie_break = &"by_vibes"
	var v := cfg.validate()
	t.ok(not v.is_valid(), "unknown tie_break is invalid")
	t.ok(v.has_code(EQError.TIE_BREAK_UNKNOWN), "unknown tie_break -> TIE_BREAK_UNKNOWN")


static func _test_scheduler_backend_values(t) -> void:
	var cfg := EQConfig.new()
	cfg.policy = StubPolicy.new()
	t.eq(cfg.scheduler_backend, EQConfig.SchedulerBackend.SORTED_ARRAY, "sorted-array backend is the compatibility default")
	cfg.scheduler_backend = EQConfig.SchedulerBackend.BINARY_HEAP
	t.ok(cfg.validate().is_valid(), "binary heap backend is a valid explicit opt-in")
	cfg.scheduler_backend = 99
	var v := cfg.validate()
	t.ok(not v.is_valid(), "unknown scheduler backend is invalid")
	t.ok(v.has_code(EQError.CONFIG_SCHEDULER_BACKEND_UNKNOWN), "unknown scheduler backend -> stable config code")


static func _test_tres_roundtrip(t) -> void:
	var cfg := EQConfig.new()
	var pol := EQPolicy.new()
	pol.policy_name = &"demo"
	cfg.policy = pol
	cfg.tie_break = &"actor_id"
	cfg.scheduler_backend = EQConfig.SchedulerBackend.BINARY_HEAP
	cfg.schema_version = 1
	var path := "user://eqm_test_config_roundtrip.tres"
	var save_err := ResourceSaver.save(cfg, path)
	t.eq(save_err, OK, "EQConfig saves to .tres")
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	t.ok(loaded != null, "EQConfig loads back")
	t.eq(loaded.tie_break, &"actor_id", "tie_break survives roundtrip")
	t.eq(loaded.scheduler_backend, EQConfig.SchedulerBackend.BINARY_HEAP, "scheduler_backend survives roundtrip")
	t.eq(loaded.schema_version, 1, "schema_version survives roundtrip")
	t.ok(loaded.policy != null, "policy sub-resource survives roundtrip")
	t.eq(loaded.policy.policy_name, &"demo", "policy_name survives roundtrip")
