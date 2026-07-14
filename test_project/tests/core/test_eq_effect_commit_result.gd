extends RefCounted
## REALIZATION-EQM-EFFECT-COMMIT-RESULT-V1 acceptance coverage.

const EQReservationRuntime := preload(
	"res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd"
)
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload(
	"res://addons/event_queue_manager/resources/eq_action_definition.gd"
)
const EQCondition := preload("res://addons/event_queue_manager/resources/eq_condition.gd")
const EQEffectRecord := preload("res://addons/event_queue_manager/runtime/eq_effect_record.gd")
const EQEffectCommitResult := preload(
	"res://addons/event_queue_manager/runtime/eq_effect_commit_result.gd"
)
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")


static func run(t) -> void:
	_test_success_sweeps_ordered_views_once(t)
	_test_failure_has_no_records_or_sweep(t)
	_test_legacy_handler_is_unchanged(t)
	_test_single_resolution_rejects_registry_version_swap(t)
	_test_result_is_deterministic(t)
	_test_bundle_rejects_typed_handler_before_any_publish(t)
	_test_expiry_rejects_typed_handler_without_invocation(t)


static func _rr(actors: Array) -> EQReservationRuntime:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	for actor in actors:
		rr.runtime.register_actor(actor)
	return rr


static func _def(kind: int, delay: int = 0) -> EQActionDefinition:
	var definition := EQActionDefinition.new()
	definition.kind = kind
	definition.delay = delay
	return definition


static func _record(kind: StringName) -> EQEffectRecord:
	var record := EQEffectRecord.new()
	record.kind = kind
	return record


static func _reaction(rr: EQReservationRuntime, actor: StringName, kind: StringName) -> void:
	var definition := _def(EQActionDefinition.Kind.REACTION_PREPARATION)
	definition.duration = EQActionDefinition.DURATION_UNLIMITED
	var condition := EQCondition.new()
	condition.match_kind = kind
	rr.submit(EQReservation.new(actor, definition), condition)


static func _probe_reaction(rr: EQReservationRuntime, actor: StringName, seen: Array) -> void:
	var definition := _def(EQActionDefinition.Kind.REACTION_PREPARATION)
	definition.duration = EQActionDefinition.DURATION_UNLIMITED
	var condition := EQCondition.new()
	condition.custom_predicate = func(view: Dictionary) -> bool:
		seen.append(String(view.get("kind", "")))
		return false
	rr.submit(EQReservation.new(actor, definition), condition)


static func _test_success_sweeps_ordered_views_once(t) -> void:
	var rr := _rr([&"origin", &"first_reaction", &"second_reaction", &"probe"])
	_reaction(rr, &"first_reaction", &"fact.first")
	_reaction(rr, &"second_reaction", &"fact.second")
	var seen: Array = []
	_probe_reaction(rr, &"probe", seen)

	var first_record := _record(&"record.first")
	var second_record := _record(&"record.second")
	rr.runtime.register_effect_commit(
		&"transactional",
		func(_view: Dictionary):
			var event_views := [
				{"kind": &"fact.second", "source": &"origin", "tags": []},
				{"kind": &"fact.first", "source": &"origin", "tags": []},
			]
			return EQEffectCommitResult.make_success([first_record, second_record], event_views)
	)
	var definition := _def(EQActionDefinition.Kind.IMMEDIATE)
	definition.effect_name = &"transactional"
	var event_id := rr.submit(EQReservation.new(&"origin", definition))
	var resolved = rr.resolve_next() if event_id > 0 else null

	t.ok(resolved != null, "transactional single reservation resolves")
	t.eq(rr.last_drained.size(), 2, "SUCCESS records enter one effect chunk")
	t.eq(rr.last_drained[0].kind, &"record.first", "record order is preserved")
	t.eq(rr.last_drained[1].kind, &"record.second", "all records drain at the boundary")
	t.eq(seen, ["fact.second", "fact.first"], "ordered views are each swept exactly once")

	var ready := rr.runtime.scheduler.peek(2)
	t.eq(ready.size(), 2, "both matching reactions are scheduled")
	t.eq(ready[0].actor_id, &"second_reaction", "view order controls reaction issuance order")
	t.eq(ready[1].actor_id, &"first_reaction", "the second declared view follows")

	var outcome := rr.last_effect_commit_outcome()
	t.eq(outcome["status"], "SUCCESS", "latest outcome exposes SUCCESS")
	t.eq(outcome["effect_commit_result_version"], 1, "latest outcome is versioned")
	t.eq(outcome["event_views"][0]["kind"], &"fact.second", "outcome preserves event-view order")
	outcome["event_views"][0]["kind"] = &"mutated"
	t.eq(
		rr.last_effect_commit_outcome()["event_views"][0]["kind"],
		&"fact.second",
		"latest outcome is a read-only deep-copy surface"
	)


static func _test_failure_has_no_records_or_sweep(t) -> void:
	var rr := _rr([&"origin", &"probe"])
	var seen: Array = []
	_probe_reaction(rr, &"probe", seen)
	rr.runtime.register_effect_commit(
		&"transactional",
		func(_view: Dictionary):
			return EQEffectCommitResult.make_failure({"code": "consumer.commit_failed", "index": 2})
	)
	var definition := _def(EQActionDefinition.Kind.IMMEDIATE)
	definition.effect_name = &"transactional"
	rr.submit(EQReservation.new(&"origin", definition))
	var resolved := rr.resolve_next()

	t.ok(resolved != null, "consumer FAILURE is an observable resolved attempt")
	t.eq(rr.last_drained.size(), 0, "FAILURE contributes zero records")
	t.ok(rr.chunk.is_empty(), "FAILURE leaves the effect chunk empty")
	t.eq(seen.size(), 0, "FAILURE performs zero reaction sweeps")
	t.ok(rr.runtime.scheduler.is_empty(), "no reaction is scheduled on FAILURE")
	t.ok(rr.runtime.faults.is_empty(), "consumer FAILURE is not an EQM contract fault")
	t.ok(not rr.runtime.halted, "consumer FAILURE does not halt dev mode")
	var outcome := rr.last_effect_commit_outcome()
	t.eq(outcome["status"], "FAILURE", "latest outcome exposes FAILURE")
	t.eq(outcome["diagnostic"]["index"], 2, "consumer diagnostic is preserved")
	t.ok(not outcome.has("records"), "FAILURE shape cannot expose partial records")
	t.ok(not outcome.has("event_views"), "FAILURE shape cannot request a sweep")


static func _test_legacy_handler_is_unchanged(t) -> void:
	var rr := _rr([&"origin", &"reaction"])
	_reaction(rr, &"reaction", &"reservation")
	rr.runtime.register_effect(
		&"legacy", func(_view: Dictionary) -> Array: return [_record(&"legacy.record")]
	)
	var definition := _def(EQActionDefinition.Kind.IMMEDIATE)
	definition.effect_name = &"legacy"
	rr.submit(EQReservation.new(&"origin", definition))
	rr.resolve_next()

	t.eq(rr.last_drained.size(), 1, "legacy Array records still drain normally")
	t.eq(rr.last_drained[0].kind, &"legacy.record", "legacy record value is unchanged")
	t.eq(rr.runtime.scheduler.size(), 1, "legacy path still sweeps the raw reservation view")
	t.eq(
		rr.last_effect_commit_outcome()["event_views"][0]["kind"],
		&"reservation",
		"legacy outcome is additively normalized to its prior raw-view sweep"
	)


static func _test_single_resolution_rejects_registry_version_swap(t) -> void:
	var rr := _rr([&"origin", &"probe"])
	var seen: Array = []
	var typed_calls := {"count": 0}
	var legacy_calls := {"count": 0}
	_probe_reaction(rr, &"probe", seen)
	rr.runtime.register_effect_commit(
		&"swapped",
		func(_view: Dictionary):
			typed_calls["count"] += 1
			return EQEffectCommitResult.make_success([], [])
	)
	var definition := _def(EQActionDefinition.Kind.IMMEDIATE)
	definition.effect_name = &"swapped"
	var reservation := EQReservation.new(&"origin", definition)
	rr.submit(reservation)
	t.eq(reservation.effect_commit_result_version, 1, "first submit binds the typed registry mode")
	rr.runtime.register_effect(
		&"swapped",
		func(_view: Dictionary) -> Array:
			legacy_calls["count"] += 1
			return []
	)
	var rejected := rr.resolve_next()

	t.eq(rejected, reservation, "the swapped reservation is returned as the rejected attempt")
	t.eq(
		reservation.status,
		EQReservation.Status.INVALIDATED,
		"version swap rejects before resolution"
	)
	t.eq(typed_calls["count"], 0, "the originally bound typed handler is not invoked")
	t.eq(legacy_calls["count"], 0, "the replacement legacy handler is not invoked")
	t.eq(seen.size(), 0, "registry swap rejection performs no sweep")
	t.eq(rr.last_drained.size(), 0, "registry swap rejection contributes no records")
	t.eq(
		rr.runtime.faults.back()["code"],
		EQError.EFFECT_COMMIT_RESULT_BINDING_MISMATCH,
		"single resolution reports the stable binding mismatch"
	)
	t.eq(
		rr.last_effect_commit_outcome()["status"],
		"FAILURE",
		"binding rejection is visible through the latest outcome"
	)


static func _deterministic_run() -> Dictionary:
	var rr := _rr([&"origin", &"reaction"])
	_reaction(rr, &"reaction", &"fact")
	rr.runtime.register_effect_commit(
		&"transactional",
		func(_view: Dictionary):
			return EQEffectCommitResult.make_success(
				[_record(&"record")],
				[{"kind": &"fact", "source": &"origin", "target": &"reaction", "tags": []}]
			)
	)
	var definition := _def(EQActionDefinition.Kind.IMMEDIATE)
	definition.effect_name = &"transactional"
	rr.submit(EQReservation.new(&"origin", definition))
	rr.resolve_next()
	return {
		"outcome": rr.last_effect_commit_outcome(),
		"trace": rr.runtime.trace_jsonl(),
		"scheduled": rr.runtime.scheduler.snapshot(),
	}


static func _test_result_is_deterministic(t) -> void:
	t.eq(
		_deterministic_run(),
		_deterministic_run(),
		"identical typed inputs produce identical outcome, trace, and schedule"
	)


static func _test_bundle_rejects_typed_handler_before_any_publish(t) -> void:
	var preflight := _rr([&"owner"])
	preflight.runtime.register_effect_commit(
		&"typed", func(_view: Dictionary): return EQEffectCommitResult.make_success([], [])
	)
	var preflight_definition := _def(EQActionDefinition.Kind.IMMEDIATE)
	preflight_definition.effect_name = &"typed"
	var preflight_first := EQReservation.new(&"owner", preflight_definition)
	var preflight_second := EQReservation.new(&"owner", preflight_definition)
	var bundle_id := (
		preflight
		. submit_bundle(
			[
				preflight_first,
				preflight_second,
			]
		)
	)
	t.eq(bundle_id, &"", "submit_bundle explicitly rejects a typed member")
	t.ok(preflight.runtime.scheduler.is_empty(), "submit rejection leaves no planned members")
	t.eq(preflight_first.effect_commit_result_version, -1, "rejected bundle stays unbound")
	t.eq(preflight_second.effect_commit_result_version, -1, "all rejected members stay unbound")

	var rr := _rr([&"first", &"second"])
	var legacy_calls := {"count": 0}
	var typed_calls := {"count": 0}
	rr.runtime.register_effect(
		&"first_effect",
		func(_view: Dictionary) -> Array:
			legacy_calls["count"] += 1
			return [_record(&"must_not_publish")]
	)
	# Submit while both members are legacy, then change registration before
	# resolve. The resolve-side preflight must inspect every member before the
	# first handler is invoked.
	rr.runtime.register_effect(&"second_effect", func(_view: Dictionary) -> Array: return [])
	var first_definition := _def(EQActionDefinition.Kind.IMMEDIATE)
	first_definition.effect_name = &"first_effect"
	var second_definition := _def(EQActionDefinition.Kind.IMMEDIATE)
	second_definition.effect_name = &"second_effect"
	var first := EQReservation.new(&"first", first_definition)
	var second := EQReservation.new(&"second", second_definition)
	t.ok(rr.submit_bundle([first, second]) != &"", "legacy bundle is initially accepted")
	rr.runtime.register_effect_commit(
		&"second_effect",
		func(_view: Dictionary):
			typed_calls["count"] += 1
			return EQEffectCommitResult.make_success([], [])
	)
	rr.resolve_next()

	t.eq(legacy_calls["count"], 0, "earlier legacy member is not published before rejection")
	t.eq(typed_calls["count"], 0, "typed bundle handler is never invoked")
	t.eq(rr.last_drained.size(), 0, "rejected bundle contributes no records")
	t.ok(rr.runtime.scheduler.is_empty(), "all rejected bundle members are closed")
	t.eq(first.status, EQReservation.Status.INVALIDATED, "first bundle member is invalidated")
	t.eq(second.status, EQReservation.Status.INVALIDATED, "second bundle member is invalidated")
	t.eq(
		rr.runtime.faults.back()["code"],
		EQError.EFFECT_COMMIT_RESULT_BINDING_MISMATCH,
		"bundle registry swap uses the stable binding mismatch"
	)


static func _test_expiry_rejects_typed_handler_without_invocation(t) -> void:
	var preflight := _rr([&"owner"])
	preflight.runtime.register_effect_commit(
		&"typed_expiry", func(_view: Dictionary): return EQEffectCommitResult.make_success([], [])
	)
	var preflight_definition := _def(EQActionDefinition.Kind.REACTION_PREPARATION)
	preflight_definition.duration = 1
	preflight_definition.expiry_effect_name = &"typed_expiry"
	var preflight_reservation := EQReservation.new(&"owner", preflight_definition)
	t.eq(
		preflight.submit(preflight_reservation),
		-1,
		"submit explicitly rejects a typed expiry effect"
	)
	t.eq(
		preflight.armed_for(&"owner").size(),
		0,
		"typed expiry rejection happens before the reaction is armed"
	)
	t.ok(preflight.runtime.scheduler.is_empty(), "typed expiry rejection schedules no expiry event")
	t.eq(
		preflight_reservation.expiry_effect_commit_result_version,
		-1,
		"rejected typed expiry stays unbound"
	)

	var rr := _rr([&"owner", &"probe"])
	var expiry_calls := {"count": 0}
	var seen: Array = []
	_probe_reaction(rr, &"probe", seen)
	rr.runtime.register_effect(&"expiry", func(_view: Dictionary) -> Array: return [])
	var definition := _def(EQActionDefinition.Kind.REACTION_PREPARATION)
	definition.duration = 1
	definition.expiry_effect_name = &"expiry"
	var expiring := EQReservation.new(&"owner", definition)
	rr.submit(expiring)
	# Registration can change while armed. The expiry resolver still refuses the
	# typed handler and must not fall back to an expiry-view sweep.
	rr.runtime.register_effect_commit(
		&"expiry",
		func(_view: Dictionary):
			expiry_calls["count"] += 1
			return EQEffectCommitResult.make_success([], [])
	)
	rr.resolve_next()

	t.eq(expiry_calls["count"], 0, "typed expiry handler is never invoked")
	t.eq(seen.size(), 0, "unsupported typed expiry has no fallback sweep")
	t.eq(rr.last_drained.size(), 0, "unsupported typed expiry contributes no records")
	t.eq(expiring.status, EQReservation.Status.INVALIDATED, "duration still closes the arm")
	t.eq(
		rr.runtime.faults.back()["code"],
		EQError.EFFECT_COMMIT_RESULT_BINDING_MISMATCH,
		"expiry registry swap uses the stable binding mismatch"
	)
