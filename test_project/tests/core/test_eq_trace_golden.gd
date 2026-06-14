extends RefCounted
## EQM-013: golden approval gate for the canonical scheduler trace. A normal run
## compares the produced trace to the fixture exactly (read-only). The fixture is
## re-baselined only via the explicit flag (./tools/test.sh --update-golden
## core_scheduler_basic), per DETERMINISM_TRACE_TEST_POLICY §2 — never on a
## normal run. On mismatch the produced trace is written under the run's traces/
## dir for diffing.

const EQScheduler := preload("res://addons/event_queue_manager/runtime/eq_scheduler.gd")
const EQTrace := preload("res://addons/event_queue_manager/runtime/eq_trace.gd")

const CASE := "core_scheduler_basic"
const GOLDEN_PATH := "res://tests/golden/core_scheduler_basic.trace.jsonl"


## Fixed, hand-authored scenario that exercises every decided_by branch:
## an early move, a rescheduled cast, a priority tie, and a sequence tie.
static func _scenario() -> EQScheduler:
	var s := EQScheduler.new()
	s.push(10, 0, &"atk", &"hero")            # id1 seq0
	s.push(10, 5, &"atk", &"orc")             # id2 seq1
	s.push(4, 0, &"move", &"hero")            # id3 seq2
	var slow := s.push(20, 0, &"cast", &"mage")  # id4 seq3
	s.push(10, 5, &"atk", &"goblin")          # id5 seq4
	s.reschedule(slow, 6)                     # id4 -> tick 6, seq5, generation 1
	return s


static func run(t) -> void:
	var jsonl := EQTrace.trace_run(_scenario()).to_jsonl()
	var update := OS.get_environment("GODOT_UPDATE_GOLDEN")

	if update == CASE:
		_write_golden(t, jsonl)
		return

	var exists := FileAccess.file_exists(GOLDEN_PATH)
	t.ok(exists, "golden fixture exists: %s (create via ./tools/test.sh --update-golden %s)" % [GOLDEN_PATH, CASE])
	if not exists:
		return
	var want := FileAccess.get_file_as_string(GOLDEN_PATH)
	if jsonl != want:
		_dump_actual(jsonl)
	t.eq(jsonl, want, "trace matches golden (re-baseline: ./tools/test.sh --update-golden %s)" % CASE)


static func _write_golden(t, jsonl: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOLDEN_PATH.get_base_dir()))
	var f := FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
	if f == null:
		t.ok(false, "could not open golden for write: %s" % GOLDEN_PATH)
		return
	f.store_string(jsonl)
	f.close()
	t.ok(true, "golden re-baselined for %s via --update-golden (record diff + reason in self-review)" % CASE)


static func _dump_actual(jsonl: String) -> void:
	var out := OS.get_environment("EQ_RUN_OUT")
	if out == "":
		return
	DirAccess.make_dir_recursive_absolute(out + "/traces")
	var f := FileAccess.open(out + "/traces/%s.actual.jsonl" % CASE, FileAccess.WRITE)
	if f != null:
		f.store_string(jsonl)
		f.close()
