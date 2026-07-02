extends RefCounted
## EQM-119 — the FROZEN §5.6 acceptance criterion: "counterattack preparation —
## closes on 3 uses OR 5 turns, deadline ∞ allowed" is declared in ONE checked-in
## .tres with ZERO GDScript lines in the declaration, and the trace's closed_by
## shows which condition closed it (golden-pinned via the dogfood L2 path).

const EQReservationRuntime := preload("res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd")
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQCondition := preload("res://addons/event_queue_manager/resources/eq_condition.gd")
const Battle := preload("res://dogfood/action_resolution/battle.gd")

const TRES_PATH := "res://dogfood/action_resolution/counterattack_preparation.tres"
const GOLDEN_CASE := "authoring_counterattack"
const GOLDEN_PATH := "res://tests/golden/authoring_counterattack.trace.jsonl"


static func run(t) -> void:
	_test_declaration_loads(t)
	_test_closure_semantics_visible_from_the_asset(t)
	_test_closures_in_trace(t)
	_test_deadline_unlimited_variant(t)
	_golden(t)


static func _test_declaration_loads(t) -> void:
	var def = ResourceLoader.load(TRES_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	t.ok(def != null, "the checked-in declaration loads (one .tres, zero GDScript lines)")
	t.ok(def.validate().is_valid(), "the declaration validates")
	t.eq(def.kind, EQActionDefinition.Kind.REACTION_PREPARATION, "kind is a reaction preparation")
	t.eq(def.duration, 5, "closes after 5 ticks ...")
	t.eq(def.rumination, 2, "... OR after 3 uses (rumination 2 = 3 total fires)")
	t.eq(def.effect_name, &"counterattack", "the effect is declared by NAME (linkage, §6.1)")
	t.eq(def.priority, 5, "the counter's ordering priority is authored data")


static func _test_closure_semantics_visible_from_the_asset(t) -> void:
	var def = ResourceLoader.load(TRES_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	var inv: Array = def.normalized_conditions()["invalidation"]
	var ids := inv.map(func(s): return s.condition_id)
	t.ok(ids.has(&"duration") and ids.has(&"reaction_count"), "the OR closure set (duration | reaction_count) is derivable from the asset alone (§5.6 sugar)")


static func _test_closures_in_trace(t) -> void:
	var jsonl := Battle.run_l2_trace()
	t.ok('"closed_by":"reaction_count"' in jsonl, "the used-up preparation closed by COUNT — visible in the trace")
	t.ok('"closed_by":"duration"' in jsonl, "the unused preparation closed by DURATION (its expiry event)")
	t.ok('"closed_by":"already_closed"' in jsonl, "the stale expiry after a count-closure is the lightweight record")
	t.eq(jsonl.count('"kind":"reaction_fired"'), 3, "exactly 3 uses fired before the count closed the slot")


static func _test_deadline_unlimited_variant(t) -> void:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	rr.runtime.register_actor(&"hero")
	rr.runtime.register_actor(&"orc")
	var def = ResourceLoader.load(TRES_PATH, "", ResourceLoader.CACHE_MODE_IGNORE).duplicate()
	def.duration = EQActionDefinition.DURATION_UNLIMITED  # deadline ∞ (Q06)
	def.effect_name = &""  # effect-less for this variant (no handler registered)
	t.ok(def.validate().is_valid(), "deadline ∞ is a legal declaration (closes only by count)")
	var cond := EQCondition.new()
	cond.match_target = &"hero"
	cond.require_tags = [&"damage"]
	rr.submit(EQReservation.new(&"hero", def), cond)
	t.ok(rr.runtime.scheduler.is_empty(), "deadline ∞ schedules NO expiry event")
	for _i in 10:
		rr.step_tick()
	t.eq(rr.armed_for(&"hero").size(), 1, "the ∞ preparation outlives any tick horizon (count is its only closure)")


static func _golden(t) -> void:
	var jsonl := Battle.run_l2_trace()
	var update := OS.get_environment("GODOT_UPDATE_GOLDEN")
	if update == GOLDEN_CASE:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOLDEN_PATH.get_base_dir()))
		var f := FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
		if f == null:
			t.ok(false, "could not open golden for write: %s" % GOLDEN_PATH)
			return
		f.store_string(jsonl)
		f.close()
		t.ok(true, "golden re-baselined for %s via --update-golden (record in self-review)" % GOLDEN_CASE)
		return
	var exists := FileAccess.file_exists(GOLDEN_PATH)
	t.ok(exists, "golden fixture exists: %s (create via ./tools/test.sh --update-golden %s)" % [GOLDEN_PATH, GOLDEN_CASE])
	if not exists:
		return
	var want := FileAccess.get_file_as_string(GOLDEN_PATH)
	if jsonl != want:
		var out := OS.get_environment("EQ_RUN_OUT")
		if out != "":
			DirAccess.make_dir_recursive_absolute(out + "/traces")
			var f := FileAccess.open(out + "/traces/%s.actual.jsonl" % GOLDEN_CASE, FileAccess.WRITE)
			if f != null:
				f.store_string(jsonl)
				f.close()
	t.eq(jsonl, want, "the counterattack closure trace matches golden (re-baseline: ./tools/test.sh --update-golden %s)" % GOLDEN_CASE)
