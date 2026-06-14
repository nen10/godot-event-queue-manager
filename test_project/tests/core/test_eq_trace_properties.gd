extends RefCounted
## EQM-013: determinism properties over the canonical trace —
## replay determinism, permutation invariance, snapshot continuity,
## explanation-as-data (decided_by) integrity, and open record-kind schema.

const EQScheduler := preload("res://addons/event_queue_manager/runtime/eq_scheduler.gd")
const EQTrace := preload("res://addons/event_queue_manager/runtime/eq_trace.gd")
const EQEntry := preload("res://addons/event_queue_manager/runtime/eq_entry.gd")
const EQSortedArrayBackend := preload("res://addons/event_queue_manager/runtime/backends/eq_sorted_array_backend.gd")


static func run(t) -> void:
	_test_replay_determinism(t)
	_test_permutation_invariance(t)
	_test_snapshot_continuity(t)
	_test_decided_by_integrity(t)
	_test_open_kind_schema(t)


# --- replay determinism ---------------------------------------------------

## Deterministically generates a scenario from a seed. The RNG drives only the
## scenario shape (it is not scheduler-internal randomness — that is EQM-072), so
## the same seed must reproduce a byte-identical trace.
static func _build_seeded(seed: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var s := EQScheduler.new()
	var ids: Array[int] = []
	for n in 12:
		ids.append(s.push(rng.randi_range(0, 20), rng.randi_range(0, 5), &"act", StringName("u%d" % (n % 4))))
	s.cancel(ids[3])
	s.reschedule(ids[7], rng.randi_range(0, 20))
	return EQTrace.trace_run(s).to_jsonl()


static func _test_replay_determinism(t) -> void:
	var a := _build_seeded(42)
	var b := _build_seeded(42)
	t.eq(a, b, "same seed -> byte-identical trace (replay determinism)")
	t.ok(a != _build_seeded(43), "different seed -> different trace")
	t.ok(a.contains("\"kind\":\"resolved\""), "trace records resolved events")


# --- permutation invariance ----------------------------------------------

## Fixed entries (same tick/priority/seq set) inserted in different orders yield
## the same ordered() — pop order is independent of insertion order, so sort
## stability is irrelevant (DETERMINISM_TRACE_TEST_POLICY §3).
static func _test_permutation_invariance(t) -> void:
	var entries: Array[EQEntry] = [
		EQEntry.make(1, 5, 0, 0),
		EQEntry.make(2, 5, 0, 1),  # tie with id1 on tick+priority, later seq
		EQEntry.make(3, 2, 0, 2),
		EQEntry.make(4, 5, 9, 3),  # higher priority at tick 5
		EQEntry.make(5, 5, 0, 4),
	]
	var forward := EQSortedArrayBackend.new()
	for e in entries:
		forward.insert(e)
	var reversed := EQSortedArrayBackend.new()
	for i in range(entries.size() - 1, -1, -1):
		reversed.insert(entries[i])
	var get_id := func(e): return e.event_id
	t.eq(reversed.ordered().map(get_id), forward.ordered().map(get_id), "ordered() independent of insertion order")
	t.eq(forward.ordered().map(get_id), [3, 4, 1, 2, 5], "ordered() is the EQOrdering total order")


# --- snapshot continuity --------------------------------------------------

static func _fixed_scenario() -> EQScheduler:
	var s := EQScheduler.new()
	s.push(7, 0, &"a", &"u0")
	s.push(3, 0, &"b", &"u1")
	var c := s.push(7, 5, &"c", &"u2")
	s.push(1, 0, &"d", &"u3")
	s.push(7, 5, &"e", &"u0")
	s.reschedule(c, 2)
	return s


## Mirrors EQTrace.trace_run's per-event recording, but as a single step so a
## snapshot/restore boundary can be inserted between events.
static func _step(tr: EQTrace, s: EQScheduler) -> void:
	var e := s.pop()
	var nxt := s.peek_next()
	tr.record_resolved(e, "timer", EQTrace._decided_by(e, nxt))


static func _test_snapshot_continuity(t) -> void:
	var uninterrupted := EQTrace.trace_run(_fixed_scenario()).to_jsonl()

	# Same scenario, but snapshot/restore after two resolutions, then continue.
	var s_a := _fixed_scenario()
	var tr := EQTrace.new()
	_step(tr, s_a)
	_step(tr, s_a)
	var s_b := EQScheduler.new()
	t.ok(s_b.restore(s_a.snapshot()) == 0, "mid-run snapshot restores OK")
	while not s_b.is_empty():
		_step(tr, s_b)
	t.eq(tr.to_jsonl(), uninterrupted, "snapshot continuity: interrupted trace == uninterrupted")


# --- explanation-as-data (decided_by) ------------------------------------

static func _test_decided_by_integrity(t) -> void:
	var s := EQScheduler.new()
	s.push(5, 0, &"x", &"a")   # seq0
	s.push(5, 0, &"x", &"b")   # seq1 -> tie with a on tick+priority
	s.push(5, 3, &"x", &"c")   # seq2 -> higher priority
	s.push(2, 0, &"x", &"d")   # seq3 -> earliest tick
	var recs := EQTrace.trace_run(s).records()
	# resolution order: d(t2), c(t5,p3), a(t5,p0,s0), b(t5,p0,s1)
	t.eq(recs[0]["tie_break"]["decided_by"], "due_tick", "earliest tick decided by due_tick")
	t.eq(recs[1]["tie_break"]["decided_by"], "priority", "equal tick decided by priority")
	t.eq(recs[2]["tie_break"]["decided_by"], "sequence", "equal tick+priority decided by sequence")
	t.eq(recs[3]["tie_break"]["decided_by"], "terminal", "last event has no successor")
	t.eq(recs[0]["i"], 0, "resolution index starts at 0")
	t.eq(recs[3]["i"], 3, "resolution index increments")
	t.eq(recs[0]["tie_break"]["compared"], ["due_tick", "priority", "sequence"], "compared keys are the int ordering keys")


# --- open record-kind schema ---------------------------------------------

## Kinds the scheduler never emits today (added by EQM-014 / EQM-061) still
## serialize canonically (sorted keys, `i` appended) with no harness change.
static func _test_open_kind_schema(t) -> void:
	var tr := EQTrace.new()
	tr.record({"kind": "event_line_progressed", "line": "global", "from": 3, "to": 4})
	tr.record({"kind": "window_opened", "window_id": 7, "tick": 10})
	var lines := tr.to_jsonl().split("\n")
	t.eq(lines[0], '{"from":3,"i":0,"kind":"event_line_progressed","line":"global","to":4}', "future kind serializes with sorted keys")
	t.eq(lines[1], '{"i":1,"kind":"window_opened","tick":10,"window_id":7}', "second future kind line is canonical")
