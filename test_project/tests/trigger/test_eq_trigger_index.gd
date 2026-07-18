extends RefCounted
## EQM-102 / EQM-136 — the trigger index returns the SAME fired set + arm order as
## the linear EQTriggerEngine scan, while only reconsidering a strict subset of
## armed reactions (the target bucket + wildcards). This is correctness/parity;
## production elapsed and work-count measurements live in res://tests/performance/.

const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQCondition := preload("res://addons/event_queue_manager/resources/eq_condition.gd")
const EQConditionSpec := preload("res://addons/event_queue_manager/resources/eq_condition_spec.gd")
const EQTriggerEngine := preload("res://addons/event_queue_manager/runtime/eq_trigger_engine.gd")
const EQTriggerIndex := preload("res://addons/event_queue_manager/runtime/eq_trigger_index.gd")

const M := 1000


static func run(t) -> void:
	_test_parity_and_speedup(t)
	_test_wildcard_matches_any_target(t)
	_test_invalid_condition_does_not_consume_sequence(t)
	_test_single_bucket_candidates_are_fresh_arrays(t)


static func _armed_set() -> Array:
	# 1000 armed reactions: bucketed across 40 targets, ~1/23 target-agnostic
	# (wildcard), half requiring a "dmg" tag.
	var out: Array = []
	for i in M:
		var def := EQActionDefinition.new()
		def.kind = EQActionDefinition.Kind.REACTION_PREPARATION
		def.duration = EQActionDefinition.DURATION_UNLIMITED
		def.rumination = 0  # one-shot, so engine fired order == arm order
		var cond := EQCondition.new()
		cond.match_target = &"" if i % 23 == 0 else StringName("a%d" % (i % 40))
		if i % 2 == 0:
			cond.require_tags = [&"dmg"]
		out.append({"reservation": EQReservation.new(StringName("owner%d" % i), def), "condition": cond})
	return out


# Reference: the linear engine's fired set, computed without mutation (arm order).
static func _linear_fired(armed: Array, view: Dictionary) -> Array:
	var fired: Array = []
	for entry in armed:
		if entry["condition"].matches(view):
			fired.append(entry["reservation"])
	return fired


static func _test_parity_and_speedup(t) -> void:
	var armed := _armed_set()
	var index := EQTriggerIndex.new()
	var engine := EQTriggerEngine.new()
	for entry in armed:
		index.add(entry["reservation"], entry["condition"])
		engine.arm(entry["reservation"], entry["condition"], 0)
	t.eq(index.size(), M, "index holds every armed reaction")

	var view := {"kind": &"hit", "source": &"x", "target": &"a5", "tags": [&"dmg"]}

	var reference := _linear_fired(armed, view)
	var indexed := index.matching_reservations(view)
	var engine_fired := engine.on_event_resolved(view, 0)  # mutates; call once

	t.ok(reference.size() > 0, "the view fires some reactions")
	t.eq(indexed, reference, "index fired set + order == linear reference")
	t.eq(engine_fired, reference, "real EQTriggerEngine fired set + order == reference (parity)")

	# speedup: candidates reconsidered are a strict subset of all armed.
	var candidates := index.candidates(view)
	t.ok(candidates.size() < M, "index reconsiders %d candidates, not all %d armed" % [candidates.size(), M])
	# every fired reaction is among the candidates (no false negatives)
	t.ok(candidates.size() >= reference.size(), "candidate set covers every fired reaction")


static func _test_wildcard_matches_any_target(t) -> void:
	# a target-agnostic (wildcard) reaction must be a candidate for ANY target.
	var index := EQTriggerIndex.new()
	var def := EQActionDefinition.new()
	def.kind = EQActionDefinition.Kind.REACTION_PREPARATION
	def.duration = EQActionDefinition.DURATION_UNLIMITED
	var wild := EQCondition.new()  # empty match_target = wildcard
	var res := EQReservation.new(&"watcher", def)
	index.add(res, wild)
	var fired := index.matching_reservations({"kind": &"hit", "target": &"anyone", "tags": []})
	t.eq(fired, [res], "wildcard reaction fires for an arbitrary target")


static func _test_invalid_condition_does_not_consume_sequence(t) -> void:
	var index := EQTriggerIndex.new()
	var definition := EQActionDefinition.new()
	definition.kind = EQActionDefinition.Kind.REACTION_PREPARATION
	definition.duration = EQActionDefinition.DURATION_UNLIMITED
	var rejected := EQReservation.new(&"rejected", definition)
	var wrong := EQConditionSpec.new()
	wrong.type = EQConditionSpec.Type.NAMED_PREDICATE
	wrong.predicate_name = &"wrong_layer"
	t.eq(index.add(rejected, wrong), -1, "index rejects a non-EQCondition")
	t.eq(index.size(), 0, "rejection mutates no bucket or sequence table")

	var accepted := EQReservation.new(&"accepted", definition)
	t.eq(index.add(accepted, EQCondition.new()), 0, "the next valid arm receives sequence zero")
	t.eq(index.size(), 1, "only the valid arm is indexed")


static func _test_single_bucket_candidates_are_fresh_arrays(t) -> void:
	var definition := EQActionDefinition.new()
	definition.kind = EQActionDefinition.Kind.REACTION_PREPARATION
	definition.duration = EQActionDefinition.DURATION_UNLIMITED

	var targeted := EQTriggerIndex.new()
	var target_condition := EQCondition.new()
	target_condition.match_target = &"hero"
	var target_reservation := EQReservation.new(&"targeted", definition)
	targeted.add(target_reservation, target_condition)
	var target_result := targeted.candidates({"target": &"hero"})
	target_result.clear()
	t.eq(
		targeted.candidates({"target": &"hero"}).map(
			func(entry): return entry["reservation"]
		),
		[target_reservation],
		"target-only candidates return a fresh array, not the derived bucket"
	)

	var wildcard := EQTriggerIndex.new()
	var wildcard_reservation := EQReservation.new(&"wildcard", definition)
	wildcard.add(wildcard_reservation, EQCondition.new())
	var wildcard_result := wildcard.candidates({"target": &"any"})
	wildcard_result.clear()
	t.eq(
		wildcard.candidates({"target": &"any"}).map(
			func(entry): return entry["reservation"]
		),
		[wildcard_reservation],
		"wildcard-only candidates return a fresh array, not the derived bucket"
	)
