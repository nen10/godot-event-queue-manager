extends RefCounted

const EQRng := preload("res://addons/event_queue_manager/runtime/eq_rng.gd")
const EQScheduler := preload("res://addons/event_queue_manager/runtime/eq_scheduler.gd")

const ACTOR_COUNT: int = 4
const INITIAL_EVENTS: int = 6
const TOTAL_EVENTS: int = 18
const TOTAL_RESOLUTIONS: int = 14
const SNAPSHOT_AFTER: int = 5


static func run(t) -> void:
	_test_same_seed_determinism(t)
	_test_save_restore_continues_stream(t)
	_test_random_order_reproduced_with_snapshot(t)


static func _test_same_seed_determinism(t) -> void:
	var rng_a: EQRng = EQRng.new(12345)
	var rng_b: EQRng = EQRng.new(12345)
	var values_a: Array[int] = []
	var values_b: Array[int] = []
	for i in 10:
		values_a.append(rng_a.randi())
		values_b.append(rng_b.randi())
	t.eq(values_a, values_b, "same seed produces the same first 10 randi values")


static func _test_save_restore_continues_stream(t) -> void:
	var rng_a: EQRng = EQRng.new(67890)
	for i in 5:
		rng_a.randi()

	var saved: Dictionary = rng_a.to_dict()
	var tail_a: Array[int] = []
	for i in 8:
		tail_a.append(rng_a.randi())

	var rng_b: EQRng = EQRng.from_saved(saved)
	var tail_b: Array[int] = []
	for i in 8:
		tail_b.append(rng_b.randi())

	t.eq(tail_b, tail_a, "from_saved continues the same randi stream after to_dict")


static func _test_random_order_reproduced_with_snapshot(t) -> void:
	var order_a: Array[String] = _run_random_order(t, 24680, -1)
	var order_b: Array[String] = _run_random_order(t, 24680, SNAPSHOT_AFTER)
	t.ok(order_a.size() > SNAPSHOT_AFTER, "random scheduler scenario resolves past the snapshot boundary")
	t.eq(order_b, order_a, "scheduler snapshot plus rng state reproduces random-dependent order")


static func _run_random_order(t, seed: int, restore_after: int) -> Array[String]:
	var rng: EQRng = EQRng.new(seed)
	var scheduler: EQScheduler = EQScheduler.new()
	var scheduled_count: int = 0
	var restored: bool = false
	var order: Array[String] = []

	for actor_index in INITIAL_EVENTS:
		var actor_id: StringName = StringName("actor_%d" % (actor_index % ACTOR_COUNT))
		_push_random_event(scheduler, rng, actor_id, scheduled_count)
		scheduled_count += 1

	while order.size() < TOTAL_RESOLUTIONS:
		var entry = scheduler.pop()
		var resolved_actor_id: StringName = entry.actor_id
		order.append("%s:%d" % [String(resolved_actor_id), entry.event_id])

		if scheduled_count < TOTAL_EVENTS:
			_push_random_event(scheduler, rng, resolved_actor_id, scheduled_count)
			scheduled_count += 1

		if restore_after >= 0 and not restored and order.size() == restore_after:
			var scheduler_snapshot: Dictionary = scheduler.snapshot()
			var rng_snapshot: Dictionary = rng.to_dict()
			var restored_scheduler: EQScheduler = EQScheduler.new()
			t.eq(restored_scheduler.restore(scheduler_snapshot), 0, "random replay scheduler restore OK")
			scheduler = restored_scheduler
			rng = EQRng.from_saved(rng_snapshot)
			restored = true

	return order


static func _push_random_event(scheduler: EQScheduler, rng: EQRng, actor_id: StringName, serial: int) -> void:
	var due_tick: int = scheduler.current_tick + rng.randi_range(1, 9)
	var priority: int = rng.randi_range(0, 3)
	var kind: StringName = StringName("roll_%d" % serial)
	scheduler.push(due_tick, priority, kind, actor_id, {"serial": serial})
