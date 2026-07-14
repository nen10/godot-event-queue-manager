extends RefCounted
## EQM-050: runtime reservation instance — validation (delegates to definition),
## counter initialisation, and serialization without live references.

const EQActionDefinition := preload(
	"res://addons/event_queue_manager/resources/eq_action_definition.gd"
)
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")


static func run(t) -> void:
	_test_init_and_validate(t)
	_test_missing_definition(t)
	_test_serialization(t)


static func _test_init_and_validate(t) -> void:
	var def := EQActionDefinition.new()
	def.kind = EQActionDefinition.Kind.PREPARED
	def.delay = 5
	def.rumination = 3
	def.duration = 2
	var r := EQReservation.new(&"hero", def)
	t.eq(r.actor_id, &"hero", "reservation carries actor_id")
	t.eq(r.remaining_ruminations, 3, "ruminations initialised from definition")
	t.eq(r.remaining_duration, 2, "duration initialised from definition")
	t.eq(r.status, EQReservation.Status.PENDING, "starts PENDING")
	t.eq(r.effect_commit_result_version, -1, "main effect mode starts unbound")
	t.eq(r.expiry_effect_commit_result_version, -1, "expiry effect mode starts unbound")
	t.ok(r.validate().is_valid(), "valid definition -> valid reservation")

	var bad := EQReservation.new(&"hero", _bad_def())
	t.ok(not bad.validate().is_valid(), "invalid definition -> invalid reservation")
	t.ok(
		bad.validate().has_code(EQError.RESERVATION_PREPARED_ZERO_DELAY),
		"instance surfaces the definition's code"
	)

	var bad_version := EQReservation.new(&"hero", def)
	bad_version.effect_commit_result_version = 2
	t.ok(not bad_version.validate().is_valid(), "unknown bound effect result version is invalid")
	t.ok(
		bad_version.validate().has_code(EQError.EFFECT_COMMIT_RESULT_VERSION_UNSUPPORTED),
		"unknown binding uses the stable version error"
	)


static func _bad_def() -> EQActionDefinition:
	var d := EQActionDefinition.new()
	d.kind = EQActionDefinition.Kind.PREPARED  # delay 0 -> invalid
	return d


static func _test_missing_definition(t) -> void:
	var r := EQReservation.new(&"hero", null)
	var v := r.validate()
	t.ok(not v.is_valid(), "no definition -> invalid")
	t.ok(v.has_code(EQError.RESERVATION_MISSING_DEFINITION), "no definition -> missing_definition")


static func _test_serialization(t) -> void:
	var def := EQActionDefinition.new()
	def.kind = EQActionDefinition.Kind.REACTION_PREPARATION
	def.duration = EQActionDefinition.DURATION_UNLIMITED
	def.tags = [&"counter"]
	var r := EQReservation.new(&"knight", def)
	r.event_id = 42
	r.status = EQReservation.Status.ARMED
	r.remaining_duration = -1
	r.effect_commit_result_version = 1
	r.expiry_effect_commit_result_version = 0
	var d := r.to_dict()
	t.ok(d["definition"] is Dictionary, "definition inlined by value (no live reference)")
	var back := EQReservation.from_dict(d)
	t.eq(back.actor_id, &"knight", "actor_id roundtrips")
	t.eq(back.event_id, 42, "event_id roundtrips")
	t.eq(back.status, EQReservation.Status.ARMED, "status roundtrips")
	t.eq(
		back.definition.kind,
		EQActionDefinition.Kind.REACTION_PREPARATION,
		"definition kind roundtrips"
	)
	t.eq(back.definition.tags, [&"counter"] as Array[StringName], "definition tags roundtrip")
	t.eq(back.effect_commit_result_version, 1, "main effect result binding roundtrips")
	t.eq(back.expiry_effect_commit_result_version, 0, "expiry effect result binding roundtrips")

	d.erase("effect_commit_result_version")
	d.erase("expiry_effect_commit_result_version")
	var historical := EQReservation.from_dict(d)
	t.eq(
		historical.effect_commit_result_version,
		0,
		"historical missing main binding defaults legacy"
	)
	t.eq(
		historical.expiry_effect_commit_result_version,
		0,
		"historical missing expiry binding defaults legacy"
	)
