extends RefCounted
## EQM-053: policy reducibility proofs. Dedicated CTB, Energy, and Wait Turn
## policies must resolve actors in the same order as independent per-tick
## event-line simulations for the same actors and action costs.

const EQRuntime := preload("res://addons/event_queue_manager/runtime/eq_runtime.gd")
const EQActionResult := preload("res://addons/event_queue_manager/runtime/eq_action_result.gd")
const EQCTBPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_ctb_policy.gd")
const EQEnergyPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_energy_policy.gd")
const EQWaitTurnPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_wait_turn_policy.gd")

const CTB_BASE_COST: int = 100
const CTB_SCALE: int = 100
const ENERGY_THRESHOLD: int = 100
const ENERGY_BASE_COST: int = 100
const WAIT_BASE_COST: int = 100


static func run(t) -> void:
	_test_ctb_reducibility(t)
	_test_energy_reducibility(t)
	_test_wait_turn_reducibility(t)


static func _test_ctb_reducibility(t) -> void:
	var cases: Array = [
		{
			"name": "speed/cost matrix",
			"turns": 18,
			"actors": [
				{"id": &"quick", "speed": 25, "costs": [100, 75, 150]},
				{"id": &"steady", "speed": 10, "costs": [100, 200, 50]},
				{"id": &"heavy", "speed": 40, "costs": [200, 100, 50]},
			],
		},
		{
			"name": "equal due/priority falls back to sequence",
			"turns": 12,
			"actors": [
				{"id": &"first", "speed": 20, "costs": [100]},
				{"id": &"second", "speed": 20, "costs": [100]},
				{"id": &"slow", "speed": 10, "costs": [100]},
			],
		},
		{
			"name": "non-divisor speeds (general no-carry equivalence)",
			"turns": 15,
			"actors": [
				{"id": &"odd", "speed": 30, "costs": [100, 150]},
				{"id": &"prime", "speed": 7, "costs": [100]},
				{"id": &"mid", "speed": 13, "costs": [100, 50]},
			],
		},
	]
	for i in range(cases.size()):
		var c: Dictionary = cases[i]
		var actors: Array = c["actors"]
		var turns: int = int(c["turns"])
		var actual: Array = _ctb_runtime_order(actors, turns)
		var expected: Array = _ctb_tick_order(actors, turns)
		t.eq(actual, expected, "CTB reduces to per-tick event-line (%s)" % String(c["name"]))


static func _test_energy_reducibility(t) -> void:
	var cases: Array = [
		{
			"name": "speed/cost/carry matrix",
			"turns": 20,
			"actors": [
				{"id": &"swift", "speed": 17, "costs": [100, 50, 150]},
				{"id": &"even", "speed": 10, "costs": [100, 200, 50]},
				{"id": &"slow", "speed": 7, "costs": [75, 125, 100]},
			],
		},
		{
			"name": "equal threshold falls back to sequence",
			"turns": 12,
			"actors": [
				{"id": &"first", "speed": 10, "costs": [100]},
				{"id": &"second", "speed": 10, "costs": [100]},
				{"id": &"third", "speed": 20, "costs": [200]},
			],
		},
	]
	for i in range(cases.size()):
		var c: Dictionary = cases[i]
		var actors: Array = c["actors"]
		var turns: int = int(c["turns"])
		var actual: Array = _energy_runtime_order(actors, turns)
		var expected: Array = _energy_tick_order(actors, turns)
		t.eq(actual, expected, "Energy reduces to per-tick event-line (%s)" % String(c["name"]))


static func _test_wait_turn_reducibility(t) -> void:
	var cases: Array = [
		{
			"name": "wait/cost/agility matrix",
			"turns": 18,
			"actors": [
				{"id": &"quick", "wait": 3, "agility": 5, "costs": [6, 2, 5]},
				{"id": &"heavy", "wait": 5, "agility": 7, "costs": [4, 8, 3]},
				{"id": &"late", "wait": 8, "agility": 1, "costs": [3, 9]},
			],
		},
		{
			"name": "equal wait uses agility then sequence",
			"turns": 12,
			"actors": [
				{"id": &"low_first", "wait": 4, "agility": 2, "costs": [4]},
				{"id": &"high", "wait": 4, "agility": 9, "costs": [4]},
				{"id": &"low_second", "wait": 4, "agility": 2, "costs": [4]},
			],
		},
	]
	for i in range(cases.size()):
		var c: Dictionary = cases[i]
		var actors: Array = c["actors"]
		var turns: int = int(c["turns"])
		var actual: Array = _wait_runtime_order(actors, turns)
		var expected: Array = _wait_tick_order(actors, turns)
		t.eq(actual, expected, "Wait Turn reduces to per-tick event-line (%s)" % String(c["name"]))


static func _ctb_runtime_order(actors: Array, turns: int) -> Array:
	var rt := EQRuntime.new()
	var policy := EQCTBPolicy.new()
	for i in range(actors.size()):
		var actor: Dictionary = actors[i]
		var actor_id: StringName = actor["id"]
		var state = rt.register_actor(actor_id)
		state.data["speed"] = int(actor.get("speed", 1))
	policy.seed(rt, rt.registry.actor_ids())
	return _runtime_order(rt, policy, actors, turns)


static func _energy_runtime_order(actors: Array, turns: int) -> Array:
	var rt := EQRuntime.new()
	var policy := EQEnergyPolicy.new()
	for i in range(actors.size()):
		var actor: Dictionary = actors[i]
		var actor_id: StringName = actor["id"]
		var state = rt.register_actor(actor_id)
		state.data["speed"] = int(actor.get("speed", 1))
	policy.seed(rt, rt.registry.actor_ids())
	return _runtime_order(rt, policy, actors, turns)


static func _wait_runtime_order(actors: Array, turns: int) -> Array:
	var rt := EQRuntime.new()
	var policy := EQWaitTurnPolicy.new()
	for i in range(actors.size()):
		var actor: Dictionary = actors[i]
		var actor_id: StringName = actor["id"]
		var state = rt.register_actor(actor_id)
		state.data["wait"] = int(actor.get("wait", 0))
		state.data["agility"] = int(actor.get("agility", 0))
	policy.seed(rt, rt.registry.actor_ids())
	return _runtime_order(rt, policy, actors, turns)


static func _runtime_order(rt, policy, actors: Array, turns: int) -> Array:
	var out: Array = []
	var actors_by_id: Dictionary = _actors_by_id(actors)
	var counts: Dictionary = {}
	for _i in range(turns):
		var e = rt.advance()
		if e == null:
			break
		var actor_id: StringName = e.actor_id
		out.append(actor_id)
		var cost: int = _next_cost(actors_by_id, counts, actor_id)
		policy.on_turn_finished(rt, actor_id, EQActionResult.new(cost, 0))
	return out


static func _ctb_tick_order(actors: Array, turns: int) -> Array:
	var out: Array = []
	var actors_by_id: Dictionary = _actors_by_id(actors)
	var counts: Dictionary = {}
	var actor_ids: Array = _actor_ids(actors)
	var state: Dictionary = {}
	var next_seq: int = 0
	for i in range(actors.size()):
		var actor: Dictionary = actors[i]
		var actor_id: StringName = actor["id"]
		var speed: int = maxi(1, int(actor.get("speed", 1)))
		state[actor_id] = {
			"charge": 0,
			"threshold": CTB_BASE_COST * CTB_SCALE,
			"speed": speed,
			"seq": next_seq,
			"armed": true,
		}
		next_seq += 1

	var ready: Array = []
	while out.size() < turns:
		if ready.is_empty():
			for i in range(actor_ids.size()):
				var actor_id: StringName = actor_ids[i]
				var s: Dictionary = state[actor_id]
				if bool(s["armed"]):
					var charge: int = int(s["charge"]) + int(s["speed"])
					var threshold: int = int(s["threshold"])
					if charge >= threshold:
						ready.append({"id": actor_id, "priority": int(s["speed"]), "seq": int(s["seq"])})
						s["armed"] = false
					s["charge"] = charge
					state[actor_id] = s

		while not ready.is_empty() and out.size() < turns:
			var idx: int = _best_ready_index(ready)
			var entry: Dictionary = ready[idx]
			ready.remove_at(idx)
			var actor_id: StringName = entry["id"]
			out.append(actor_id)

			var s: Dictionary = state[actor_id]
			var cost: int = _next_cost(actors_by_id, counts, actor_id)
			var spend: int = cost if cost > 0 else CTB_BASE_COST
			# EQCTBPolicy is no-carry: it reschedules at ceil(cost*scale/speed) each
			# turn with no accumulated-charge carry-over, so the per-tick line must
			# reset charge to 0 to match it for all speeds (carrying would diverge by
			# a rounding remainder when speed does not divide the threshold). Energy,
			# by contrast, does carry — see _energy_tick_order.
			s["charge"] = 0
			s["threshold"] = spend * CTB_SCALE
			s["seq"] = next_seq
			s["armed"] = true
			next_seq += 1
			state[actor_id] = s
	return out


static func _energy_tick_order(actors: Array, turns: int) -> Array:
	var out: Array = []
	var actors_by_id: Dictionary = _actors_by_id(actors)
	var counts: Dictionary = {}
	var actor_ids: Array = _actor_ids(actors)
	var state: Dictionary = {}
	var next_seq: int = 0
	for i in range(actors.size()):
		var actor: Dictionary = actors[i]
		var actor_id: StringName = actor["id"]
		state[actor_id] = {
			"energy": 0,
			"speed": maxi(1, int(actor.get("speed", 1))),
			"seq": next_seq,
			"armed": true,
		}
		next_seq += 1

	var ready: Array = []
	while out.size() < turns:
		if ready.is_empty():
			for i in range(actor_ids.size()):
				var actor_id: StringName = actor_ids[i]
				var s: Dictionary = state[actor_id]
				if bool(s["armed"]):
					var energy: int = int(s["energy"]) + int(s["speed"])
					if energy >= ENERGY_THRESHOLD:
						ready.append({"id": actor_id, "priority": 0, "seq": int(s["seq"])})
						s["armed"] = false
					s["energy"] = energy
					state[actor_id] = s

		while not ready.is_empty() and out.size() < turns:
			var idx: int = _best_ready_index(ready)
			var entry: Dictionary = ready[idx]
			ready.remove_at(idx)
			var actor_id: StringName = entry["id"]
			out.append(actor_id)

			var s: Dictionary = state[actor_id]
			var cost: int = _next_cost(actors_by_id, counts, actor_id)
			var spend: int = cost if cost > 0 else ENERGY_BASE_COST
			s["energy"] = int(s["energy"]) - spend
			s["seq"] = next_seq
			s["armed"] = true
			next_seq += 1
			state[actor_id] = s
	return out


static func _wait_tick_order(actors: Array, turns: int) -> Array:
	var out: Array = []
	var actors_by_id: Dictionary = _actors_by_id(actors)
	var counts: Dictionary = {}
	var actor_ids: Array = _actor_ids(actors)
	var state: Dictionary = {}
	var next_seq: int = 0
	var ready: Array = []
	for i in range(actors.size()):
		var actor: Dictionary = actors[i]
		var actor_id: StringName = actor["id"]
		var wait: int = maxi(0, int(actor.get("wait", 0)))
		var agility: int = int(actor.get("agility", 0))
		state[actor_id] = {
			"wait": wait,
			"agility": agility,
			"seq": next_seq,
			"armed": wait > 0,
		}
		if wait <= 0:
			ready.append({"id": actor_id, "priority": agility, "seq": next_seq})
		next_seq += 1

	while out.size() < turns:
		if ready.is_empty():
			for i in range(actor_ids.size()):
				var actor_id: StringName = actor_ids[i]
				var s: Dictionary = state[actor_id]
				if bool(s["armed"]):
					var wait: int = int(s["wait"]) - 1
					if wait <= 0:
						ready.append({"id": actor_id, "priority": int(s["agility"]), "seq": int(s["seq"])})
						s["armed"] = false
					s["wait"] = wait
					state[actor_id] = s

		while not ready.is_empty() and out.size() < turns:
			var idx: int = _best_ready_index(ready)
			var entry: Dictionary = ready[idx]
			ready.remove_at(idx)
			var actor_id: StringName = entry["id"]
			out.append(actor_id)

			var s: Dictionary = state[actor_id]
			var cost: int = _next_cost(actors_by_id, counts, actor_id)
			var next_wait: int = cost if cost > 0 else WAIT_BASE_COST
			s["wait"] = maxi(1, next_wait)
			s["seq"] = next_seq
			s["armed"] = true
			next_seq += 1
			state[actor_id] = s
	return out


static func _best_ready_index(ready: Array) -> int:
	var best: int = 0
	for i in range(1, ready.size()):
		var candidate: Dictionary = ready[i]
		var current: Dictionary = ready[best]
		var candidate_priority: int = int(candidate["priority"])
		var current_priority: int = int(current["priority"])
		if candidate_priority > current_priority:
			best = i
		elif candidate_priority == current_priority:
			var candidate_seq: int = int(candidate["seq"])
			var current_seq: int = int(current["seq"])
			if candidate_seq < current_seq:
				best = i
	return best


static func _actors_by_id(actors: Array) -> Dictionary:
	var out: Dictionary = {}
	for i in range(actors.size()):
		var actor: Dictionary = actors[i]
		var actor_id: StringName = actor["id"]
		out[actor_id] = actor
	return out


static func _actor_ids(actors: Array) -> Array:
	var out: Array = []
	for i in range(actors.size()):
		var actor: Dictionary = actors[i]
		var actor_id: StringName = actor["id"]
		out.append(actor_id)
	return out


static func _next_cost(actors_by_id: Dictionary, counts: Dictionary, actor_id: StringName) -> int:
	var actor: Dictionary = actors_by_id[actor_id]
	var costs: Array = actor.get("costs", [100])
	var index: int = int(counts.get(actor_id, 0))
	counts[actor_id] = index + 1
	if costs.is_empty():
		return 100
	var cost: int = int(costs[index % costs.size()])
	return cost
