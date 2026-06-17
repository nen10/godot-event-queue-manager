extends RefCounted
## EQM-061: reaction preparation runtime — a counterattack triggers on incoming
## damage, duration expiry prevents the trigger, and owner/source matching keeps
## a reaction from firing on the owner's own actions.

const EQTriggerEngine := preload("res://addons/event_queue_manager/runtime/eq_trigger_engine.gd")
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQCondition := preload("res://addons/event_queue_manager/resources/eq_condition.gd")


static func run(t) -> void:
	_test_fires_on_incoming_damage(t)
	_test_duration_expiry_prevents_trigger(t)
	_test_owner_source_matching(t)
	_test_one_shot_and_no_match(t)


## A REACTION_PREPARATION reservation owned by `owner`.
static func _reaction(owner: StringName, duration: int) -> EQReservation:
	var def := EQActionDefinition.new()
	def.kind = EQActionDefinition.Kind.REACTION_PREPARATION
	def.duration = duration
	def.tags = [&"counter"]
	return EQReservation.new(owner, def)


## A condition: incoming damage targeting `owner` from someone else.
static func _counter_condition(owner: StringName) -> EQCondition:
	var c := EQCondition.new()
	c.match_target = owner
	c.require_tags = [&"damage"]
	c.custom_predicate = func(view): return view.get("source", &"") != owner
	return c


static func _damage_view(source: StringName, target: StringName) -> Dictionary:
	return {"kind": &"hit", "source": source, "target": target, "tags": [&"damage"]}


static func _test_fires_on_incoming_damage(t) -> void:
	var eng := EQTriggerEngine.new()
	eng.arm(_reaction(&"hero", EQActionDefinition.DURATION_UNLIMITED), _counter_condition(&"hero"), 0)
	var fired := eng.on_event_resolved(_damage_view(&"orc", &"hero"), 1)
	t.eq(fired.size(), 1, "counterattack fires on incoming damage to its owner")
	t.eq(fired[0].actor_id, &"hero", "the owner's reaction fired")
	t.eq(fired[0].status, EQReservation.Status.RESOLVED, "fired reaction is RESOLVED")


static func _test_duration_expiry_prevents_trigger(t) -> void:
	var eng := EQTriggerEngine.new()
	eng.arm(_reaction(&"hero", 5), _counter_condition(&"hero"), 0)  # armed at 0, lasts 5 ticks
	# matching damage arrives after the window closed
	var fired := eng.on_event_resolved(_damage_view(&"orc", &"hero"), 8)
	t.eq(fired.size(), 0, "expired reaction does not fire (8 - 0 > 5)")
	t.eq(eng.armed_count(), 0, "expired reaction was dropped")


static func _test_owner_source_matching(t) -> void:
	var eng := EQTriggerEngine.new()
	eng.arm(_reaction(&"hero", EQActionDefinition.DURATION_UNLIMITED), _counter_condition(&"hero"), 0)
	# damage to someone else -> no trigger (target != owner)
	t.eq(eng.on_event_resolved(_damage_view(&"orc", &"goblin"), 1).size(), 0, "no fire when damage targets another actor")
	# the owner's own action (self as source) -> no trigger (custom predicate rejects source == owner)
	t.eq(eng.on_event_resolved(_damage_view(&"hero", &"hero"), 1).size(), 0, "no fire on the owner's own damage source")
	t.eq(eng.armed_count(), 1, "reaction stays armed through non-matching events")
	# a genuine enemy hit fires
	t.eq(eng.on_event_resolved(_damage_view(&"orc", &"hero"), 1).size(), 1, "fires on a genuine enemy hit")


static func _test_one_shot_and_no_match(t) -> void:
	var eng := EQTriggerEngine.new()
	eng.arm(_reaction(&"hero", EQActionDefinition.DURATION_UNLIMITED), _counter_condition(&"hero"), 0)
	# a non-damage event leaves it armed
	var non_damage := {"kind": &"heal", "source": &"cleric", "target": &"hero", "tags": [&"heal"]}
	t.eq(eng.on_event_resolved(non_damage, 1).size(), 0, "non-matching event does not fire")
	t.eq(eng.armed_count(), 1, "reaction remains armed after a non-match")
	# fires once, then is consumed (one-shot)
	t.eq(eng.on_event_resolved(_damage_view(&"orc", &"hero"), 2).size(), 1, "fires on damage")
	t.eq(eng.armed_count(), 0, "one-shot: consumed after firing")
	t.eq(eng.on_event_resolved(_damage_view(&"orc", &"hero"), 3).size(), 0, "no second fire")
