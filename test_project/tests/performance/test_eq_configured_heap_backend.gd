extends RefCounted
## EQM-145 independent performance lane: the consumer-facing config path can
## select the binary heap backend, and a configured heap drain is not regressed
## by the old per-resolution trace-peek full sort. The hard gates are backend
## type + declared workload completion; elapsed is a coarse advisory guard.

const EQRuntime := preload("res://addons/event_queue_manager/runtime/eq_runtime.gd")
const EQConfig := preload("res://addons/event_queue_manager/resources/eq_config.gd")
const EQFixedRoundPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_fixed_round_policy.gd")
const EQBinaryHeapBackend := preload("res://addons/event_queue_manager/runtime/backends/eq_binary_heap_backend.gd")

const HEAP_DRAIN_N := 1024
const HEAP_DRAIN_BUDGET_MS := 500


static func run(t) -> void:
	_test_configured_heap_drain_guard(t)


static func _test_configured_heap_drain_guard(t) -> void:
	var cfg := EQConfig.new()
	cfg.policy = EQFixedRoundPolicy.new()
	cfg.scheduler_backend = EQConfig.SchedulerBackend.BINARY_HEAP
	var rt := EQRuntime.new(cfg)
	rt.emit_engine_diagnostics = false
	t.ok(rt.scheduler._backend is EQBinaryHeapBackend, "config selects the binary heap backend")
	for i in HEAP_DRAIN_N:
		var tick := (i * 2654435761) % HEAP_DRAIN_N
		var priority := (i * 40503) % 7
		rt.scheduler.push(tick, priority, &"timer", &"")
	var started := Time.get_ticks_msec()
	var advanced := 0
	while rt.advance() != null:
		advanced += 1
	var elapsed := Time.get_ticks_msec() - started
	t.eq(advanced, HEAP_DRAIN_N, "configured heap drain resolves the declared workload")
	t.eq(rt.trace().size(), HEAP_DRAIN_N, "configured heap drain records one trace per resolved event")
	t.ok(elapsed < HEAP_DRAIN_BUDGET_MS, "configured heap drain stays below coarse guard: %dms < %dms" % [elapsed, HEAP_DRAIN_BUDGET_MS])
	print("[perf][EQM-145] configured heap drain N=%d elapsed=%d ms budget=%d ms" % [HEAP_DRAIN_N, elapsed, HEAP_DRAIN_BUDGET_MS])
