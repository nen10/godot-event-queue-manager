extends RefCounted
## EQM-145: EQConfig.scheduler_backend selects the scheduler backend at setup
## time, with sorted-array compatibility default and binary-heap opt-in.

const EQRuntime := preload("res://addons/event_queue_manager/runtime/eq_runtime.gd")
const EQManager := preload("res://addons/event_queue_manager/runtime/eq_manager.gd")
const EQConfig := preload("res://addons/event_queue_manager/resources/eq_config.gd")
const EQFixedRoundPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_fixed_round_policy.gd")
const EQActionResult := preload("res://addons/event_queue_manager/runtime/eq_action_result.gd")
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")
const EQSortedArrayBackend := preload("res://addons/event_queue_manager/runtime/backends/eq_sorted_array_backend.gd")
const EQBinaryHeapBackend := preload("res://addons/event_queue_manager/runtime/backends/eq_binary_heap_backend.gd")


static func run(t) -> void:
	_test_runtime_uses_sorted_default(t)
	_test_manager_configures_binary_heap_before_seed(t)
	_test_non_empty_reconfigure_rejects_without_replacing_scheduler(t)
	_test_backend_order_and_trace_parity(t)


static func _config(backend: int) -> EQConfig:
	var cfg := EQConfig.new()
	cfg.policy = EQFixedRoundPolicy.new()
	cfg.scheduler_backend = backend
	return cfg


static func _test_runtime_uses_sorted_default(t) -> void:
	var rt := EQRuntime.new(_config(EQConfig.SchedulerBackend.SORTED_ARRAY))
	t.ok(rt.scheduler._backend is EQSortedArrayBackend, "sorted-array backend is the config/default runtime backend")


static func _test_manager_configures_binary_heap_before_seed(t) -> void:
	var m := EQManager.new()
	m.runtime().emit_engine_diagnostics = false
	var cfg := _config(EQConfig.SchedulerBackend.BINARY_HEAP)
	var v = m.configure(cfg)
	t.ok(v.is_valid(), "binary heap config validates")
	t.ok(m.runtime().scheduler._backend is EQBinaryHeapBackend, "manager configure applies binary heap before seeding")
	m.register_actor(&"a").data["initiative"] = 1
	m.seed()
	t.ok(m.runtime().scheduler.has_event(1), "heap-backed manager schedules events normally")
	m.free()


static func _test_non_empty_reconfigure_rejects_without_replacing_scheduler(t) -> void:
	var m := EQManager.new()
	m.runtime().emit_engine_diagnostics = false
	m.configure(_config(EQConfig.SchedulerBackend.SORTED_ARRAY))
	m.register_actor(&"a").data["initiative"] = 1
	m.seed()
	var scheduler_before = m.runtime().scheduler
	t.ok(scheduler_before._backend is EQSortedArrayBackend, "precondition: sorted backend before rejected reconfigure")
	var faults_before := m.runtime().faults.size()
	m.configure(_config(EQConfig.SchedulerBackend.BINARY_HEAP))
	t.eq(m.runtime().scheduler, scheduler_before, "non-empty backend reconfigure keeps the existing scheduler instance")
	t.ok(m.runtime().scheduler._backend is EQSortedArrayBackend, "non-empty backend reconfigure does not replace backend")
	t.ok(m.runtime().faults.size() > faults_before, "non-empty backend reconfigure records a fault")
	t.eq(m.runtime().faults.back()["code"], EQError.RUNTIME_SCHEDULER_BACKEND_RECONFIGURE_NONEMPTY, "non-empty reconfigure uses the stable backend fault code")
	t.ok(m.runtime().scheduler.has_event(1), "live event remains scheduled after rejected reconfigure")
	m.free()


static func _test_backend_order_and_trace_parity(t) -> void:
	var sorted_trace := _run_trace(EQConfig.SchedulerBackend.SORTED_ARRAY)
	var heap_trace := _run_trace(EQConfig.SchedulerBackend.BINARY_HEAP)
	t.eq(heap_trace, sorted_trace, "binary heap backend produces the same trace as sorted-array backend")
	t.ok(sorted_trace.length() > 0, "parity scenario produced a non-empty trace")


static func _run_trace(backend: int) -> String:
	var m := EQManager.new()
	m.runtime().emit_engine_diagnostics = false
	m.configure(_config(backend))
	m.register_actor(&"fast").data["initiative"] = 9
	m.register_actor(&"mid").data["initiative"] = 5
	m.register_actor(&"slow").data["initiative"] = 1
	m.seed()
	m.advance_frame(9, EQActionResult.new(0, 0))
	var out := m.trace_jsonl()
	m.free()
	return out
