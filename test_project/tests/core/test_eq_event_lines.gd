extends RefCounted
## EQM-112: EQEventLines — data-only lines, sparse polling, deterministic scan
## orders, counter issuance, sweep rules, trace emission, dict roundtrip
## (SEM §4.3/§4.6/§4.7/§11).

const EQEventLines := preload("res://addons/event_queue_manager/runtime/eq_event_lines.gd")
const EQConditionSpec := preload("res://addons/event_queue_manager/resources/eq_condition_spec.gd")
const EQConditionEval := preload("res://addons/event_queue_manager/runtime/eq_condition_eval.gd")
const EQActionDefinition := preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQActorRegistry := preload("res://addons/event_queue_manager/runtime/eq_actor_registry.gd")
const EQTrace := preload("res://addons/event_queue_manager/runtime/eq_trace.gd")
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")


static func run(t) -> void:
	_test_issue_and_read(t)
	_test_primary_id_matches_l2_sugar(t)
	_test_advance_and_faults(t)
	_test_sparse_poll(t)
	_test_rate_modifier_effective_rate(t)
	_test_modifier_freeze_recover(t)
	_test_rate_modifier_faults(t)
	_test_scan_order_deterministic(t)
	_test_counter_issuance(t)
	_test_sync_primary(t)
	_test_trace_records(t)
	_test_modifier_trace_records(t)
	_test_dict_roundtrip(t)
	_test_dict_roundtrip_with_modifiers(t)
	_test_sweep_rules(t)
	_test_condition_integration(t)


static func _test_issue_and_read(t) -> void:
	var el := EQEventLines.new()
	t.ok(el.has_line(EQEventLines.PRIMARY_LINE_ID), "primary line exists from construction")
	t.ok(el.issue(&"party_wt", 10, 2), "issue creates a line")
	t.eq(el.value_of(&"party_wt"), 10, "issued value readable")
	t.eq(el.rate_of(&"party_wt"), 2, "issued rate readable")
	t.ok(not el.issue(&"party_wt", 0, 0), "re-issuing an existing id is refused (issuance is not update)")
	t.ok(not el.issue(&"", 0, 0), "empty id is refused")


static func _test_primary_id_matches_l2_sugar(t) -> void:
	t.eq(EQEventLines.PRIMARY_LINE_ID, EQActionDefinition.PRIMARY_LINE_ID, "L3 primary id equals the L2 sugar reference (drift guard)")


static func _test_advance_and_faults(t) -> void:
	var el := EQEventLines.new()
	el.issue(&"ct", 0, 0)
	t.ok(el.advance(&"ct", 25), "explicit advance from an effect")
	t.eq(el.value_of(&"ct"), 25, "advance adds the amount")
	t.ok(el.advance(&"ct", -10), "negative advance (decremental counter path) allowed")
	t.eq(el.value_of(&"ct"), 15, "decrement applied")

	t.ok(not el.advance(&"nope", 1), "advance on unknown line fails")
	t.eq(el.faults.size(), 1, "unknown-line advance is a recorded fault, not silent")
	t.eq(el.faults[0]["code"], EQError.CONDITION_LINE_UNKNOWN, "fault carries the stable code")
	t.ok(not el.re_rate(&"nope", 3), "re_rate on unknown line fails and records")
	t.eq(el.faults.size(), 2, "second fault recorded")


static func _test_sparse_poll(t) -> void:
	var el := EQEventLines.new()
	el.issue(&"watched_moving", 0, 5)
	el.issue(&"watched_frozen", 0, 0)
	el.issue(&"unwatched_moving", 0, 7)
	var watched := {&"watched_moving": true, &"watched_frozen": true}
	el.poll_tick(watched)
	t.eq(el.value_of(&"watched_moving"), 5, "watched non-frozen line advances by rate")
	t.eq(el.value_of(&"watched_frozen"), 0, "frozen (rate 0) line does not advance even when watched")
	t.eq(el.value_of(&"unwatched_moving"), 0, "unwatched line does not advance (sparse polling)")

	el.re_rate(&"watched_moving", 3)
	el.poll_tick(watched)
	t.eq(el.value_of(&"watched_moving"), 8, "re-rate absorbs a rate change as data (no due_tick rewrite)")


static func _test_rate_modifier_effective_rate(t) -> void:
	var el := EQEventLines.new()
	el.issue(&"ct", 0, 10)
	el.add_rate_modifier(&"ct", "add", 2)
	el.add_rate_modifier(&"ct", "add", -3)
	t.eq(el.effective_rate_of(&"ct"), 9, "adds stack additively on base rate")

	var first_override := el.add_rate_modifier(&"ct", "override", 20)
	t.eq(el.effective_rate_of(&"ct"), 20, "override replaces add effects")
	var second_override := el.add_rate_modifier(&"ct", "override", 3)
	t.eq(el.effective_rate_of(&"ct"), 3, "latest override wins when multiple overrides stacked")
	el.remove_rate_modifier(&"ct", first_override)
	t.eq(el.effective_rate_of(&"ct"), 3, "removing non-last override keeps the later override")
	el.remove_rate_modifier(&"ct", second_override)
	t.eq(el.effective_rate_of(&"ct"), 9, "removing all overrides restores base+adds")


static func _test_modifier_freeze_recover(t) -> void:
	var el := EQEventLines.new()
	el.issue(&"ct", 0, 5)
	el.add_rate_modifier(&"ct", "add", -1)
	var freeze := el.add_rate_modifier(&"ct", "override", 0)
	var watched := {&"ct": true}
	el.poll_tick(watched)
	t.eq(el.value_of(&"ct"), 0, "override 0 prevents poll advancement")
	el.remove_rate_modifier(&"ct", freeze)
	el.poll_tick(watched)
	t.eq(el.value_of(&"ct"), 4, "removing override restores remaining add-modifier effective rate")


static func _test_rate_modifier_faults(t) -> void:
	var el := EQEventLines.new()
	t.eq(el.add_rate_modifier(&"missing", "add", 1), &"", "unknown line add returns empty id")
	t.eq(el.faults.size(), 1, "unknown line fault is recorded")
	el.issue(&"ct", 0, 1)
	t.ok(not el.remove_rate_modifier(&"missing", &"eqm.mod.1"), "unknown line remove returns false")
	t.ok(not el.remove_rate_modifier(&"ct", &"eqm.mod.999"), "unknown modifier remove returns false")
	t.eq(el.faults.size(), 3, "unknown line and modifier are both recorded as faults")
	t.eq(el.add_rate_modifier(&"ct", "bad_kind", 1), &"", "invalid kind returns empty id")
	t.eq(el.faults.size(), 4, "invalid kind is recorded as a fault")


static func _test_modifier_trace_records(t) -> void:
	var tr := EQTrace.new()
	var el := EQEventLines.new(tr)
	el.issue(&"ct", 1, 2)
	var add := el.add_rate_modifier(&"ct", "add", 2)
	var override := el.add_rate_modifier(&"ct", "override", 0)
	el.remove_rate_modifier(&"ct", override)
	var jsonl := tr.to_jsonl()
	t.ok('"cause":"modifier_added"' in jsonl, "modifier add is traced")
	t.ok('"cause":"modifier_removed"' in jsonl, "modifier remove is traced")
	t.ok('"modifier_id":"%s"' % add in jsonl, "traced modifier add includes modifier_id")
	t.ok('"modifier_id":"%s"' % override in jsonl, "traced modifier remove includes modifier_id")
	t.ok('"effective_from":2' in jsonl and '"effective_to":4' in jsonl, "add record keeps effective_from/to")
	t.ok('"effective_from":0' in jsonl and '"effective_to":4' in jsonl, "remove record keeps effective_from/to")


static func _test_dict_roundtrip_with_modifiers(t) -> void:
	var el := EQEventLines.new()
	el.issue(&"ct", 7, 2)
	el.add_rate_modifier(&"ct", "add", 3)
	el.add_rate_modifier(&"ct", "override", 6)
	var d := el.to_dict()
	var back := EQEventLines.from_dict(d)
	t.eq(back.effective_rate_of(&"ct"), 6, "restored lines keep effective_rate")
	t.ok(d.has("modifier_seq"), "modifier seq is serialized")
	t.eq(back.add_rate_modifier(&"ct", "add", 1), &"eqm.mod.3", "modifier_seq continues after restore")


static func _test_scan_order_deterministic(t) -> void:
	# same lines inserted in different orders -> identical poll trace order
	var a := EQEventLines.new(EQTrace.new())
	a.issue(&"b_line", 0, 1)
	a.issue(&"a_line", 0, 1)
	var b := EQEventLines.new(EQTrace.new())
	b.issue(&"a_line", 0, 1)
	b.issue(&"b_line", 0, 1)
	var watched := {&"a_line": true, &"b_line": true}
	var trace_a := EQTrace.new()
	var trace_b := EQTrace.new()
	a.set_trace(trace_a)
	b.set_trace(trace_b)
	a.poll_tick(watched)
	b.poll_tick(watched)
	t.eq(trace_a.to_jsonl(), trace_b.to_jsonl(), "poll order is line-id ascending regardless of insertion order")


static func _test_counter_issuance(t) -> void:
	var a := EQEventLines.new()
	var c1 := a.issue_counter(3)
	var c2 := a.issue_counter(5)
	t.eq(c1, &"eqm.counter.1", "counter ids are deterministic (issuance order)")
	t.eq(c2, &"eqm.counter.2", "counter seq is monotonic")
	t.eq(a.value_of(c1), 3, "counter starts at its declared value")
	t.eq(a.rate_of(c1), 0, "counters are frozen lines (advance by explicit decrement)")

	var b := EQEventLines.new()
	t.eq(b.issue_counter(3), c1, "same call order on a fresh instance yields the same ids (replay determinism)")


static func _test_sync_primary(t) -> void:
	var el := EQEventLines.new()
	el.sync_primary(7)
	t.eq(el.value_of(EQEventLines.PRIMARY_LINE_ID), 7, "sync_primary mirrors the scheduler tick")
	var tr := EQTrace.new()
	el.set_trace(tr)
	el.sync_primary(7)
	t.eq(tr.size(), 0, "unchanged sync is a no-op (no trace noise)")


static func _test_trace_records(t) -> void:
	var tr := EQTrace.new()
	var el := EQEventLines.new(tr)
	el.issue(&"ct", 2, 1)
	el.advance(&"ct", 3)
	el.re_rate(&"ct", 4)
	el.poll_tick({&"ct": true})
	var jsonl := tr.to_jsonl()
	t.ok('"cause":"issued"' in jsonl, "issuance is traced")
	t.ok('"cause":"advanced"' in jsonl and '"from":2,"kind"' in jsonl or '"from":2' in jsonl, "advance is traced with from/to")
	t.ok('"cause":"re_rated"' in jsonl and '"rate_from":1' in jsonl and '"rate_to":4' in jsonl, "re-rate is traced with rate_from/rate_to")
	t.ok('"cause":"poll"' in jsonl and '"to":9' in jsonl, "poll is traced (5 + rate 4 = 9)")
	t.ok('"kind":"event_line_progressed"' in jsonl, "all records use the reserved kind (SEM §11)")


static func _test_dict_roundtrip(t) -> void:
	var el := EQEventLines.new()
	el.issue(&"wt", 12, -1)
	el.issue_counter(3)
	el.register_sweep_rule(&"ct_charge", func(_a, _d, _l): pass)
	var d := el.to_dict()
	t.ok(not ("callable" in JSON.stringify(d)), "serialized form carries no callables (names only)")
	var back := EQEventLines.from_dict(d)
	t.eq(back.value_of(&"wt"), 12, "value survives roundtrip")
	t.eq(back.rate_of(&"wt"), -1, "rate survives roundtrip")
	t.eq(back.value_of(&"eqm.counter.1"), 3, "counter line survives roundtrip")
	t.eq(back.issue_counter(1), &"eqm.counter.2", "counter seq continues after restore (no id reuse)")
	t.eq(d["sweep_rules"], ["ct_charge"], "sweep rule names are stored for load-time verification (EQM-117)")


static func _test_sweep_rules(t) -> void:
	var el := EQEventLines.new()
	var reg := EQActorRegistry.new()
	reg.register(&"orc")     # registered out of id order on purpose
	reg.register(&"knight")
	reg.get_state(&"knight").data["speed"] = 10
	reg.get_state(&"orc").data["speed"] = 7

	var visits := []
	el.register_sweep_rule(&"ct_charge", func(actor_id: StringName, data: Dictionary, lines) -> void:
		visits.append(actor_id)
		var line := StringName("ct.%s" % actor_id)
		if not lines.has_line(line):
			lines.issue(line, 0, 0)
		lines.advance(line, int(data.get("speed", 0))))
	el.register_sweep_rule(&"second_rule", func(_a, _d, _l): visits.append(&"second"))

	var tr := EQTrace.new()
	el.set_trace(tr)
	el.run_sweep_rules(reg)
	t.eq(visits, [&"knight", &"orc", &"second", &"second"], "registration order x actor_id ascending scan")
	t.eq(el.value_of(&"ct.knight"), 10, "per-entity param (speed) drives the shared rule (pattern 2)")
	t.eq(el.value_of(&"ct.orc"), 7, "each entity advances by its own param")
	t.ok('"cause":"sweep_rule"' in tr.to_jsonl() and '"rule":"ct_charge"' in tr.to_jsonl(), "sweep execution is traced with the rule name")

	t.ok(not el.register_sweep_rule(&"", func(_a, _d, _l): pass), "empty rule name is refused")
	t.eq(el.faults.back()["code"], EQError.CONDITION_PREDICATE_NAME_EMPTY, "empty-name refusal is a recorded fault")
	t.ok(el.register_sweep_rule(&"ct_charge", func(_a, _d, _l): pass), "re-registration replaces (idempotent setup)")
	t.eq(el.sweep_rule_names(), [&"ct_charge", &"second_rule"], "replacement keeps registration order")


static func _test_condition_integration(t) -> void:
	# CT system shape: rate 5, act at 100 (level semantics; the effect resets by -100)
	var el := EQEventLines.new()
	el.issue(&"ct.hero", 0, 5)
	var spec := EQConditionSpec.new()
	spec.type = EQConditionSpec.Type.LINE_THRESHOLD
	spec.line_id = &"ct.hero"
	spec.threshold = 100
	var term := EQConditionEval.bind(spec, "solve", 0, {"lines": el.ctx_lines()})
	var watched := EQEventLines.derive_watched([[term]])
	t.ok(watched.has(&"ct.hero"), "watched set derives from pending condition terms")

	var held_at := -1
	for i in range(25):
		el.poll_tick(watched)
		if EQConditionEval.term_holds(term, {"lines": el.ctx_lines()})["result"] == EQConditionEval.Result.YES:
			held_at = i + 1
			break
	t.eq(held_at, 20, "threshold 100 at rate 5 holds after exactly 20 polls")
	el.advance(&"ct.hero", -100)
	t.eq(EQConditionEval.term_holds(term, {"lines": el.ctx_lines()})["result"], EQConditionEval.Result.NO, "the resolving effect's reset makes the level condition drop (Q34)")
