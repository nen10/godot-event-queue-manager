extends Node
## LEARNING-PATH SAMPLE — not production. A LIFO "stack" resolution (the
## Magic-style stack: the last response cast resolves first) built with the public
## L0 API only (EQRuntime / EQEntry / EQTrace). The stack is modelled with the
## ordering comparator: items share a tick and carry priority = stack depth, so
## priority-DESC pops the deepest (last-pushed) item first. No dedicated stack
## policy — composition on the existing total order. Verified headless against a
## golden by test_project/tests/debug_scene/test_stack_resolution_demo.gd.

const EQRuntime := preload("res://addons/event_queue_manager/runtime/eq_runtime.gd")
const EQTrace := preload("res://addons/event_queue_manager/runtime/eq_trace.gd")

# (item, depth): a spell, a response on top of it, a counter on top of that.
const STACK := [
	[&"spell_fireball", 0],
	[&"response_redirect", 1],
	[&"counter_negate", 2],
]


## Pushes the stack (all at one tick, priority = depth) and resolves it. Returns a
## canonical trace; the resolution order is LIFO (counter, response, spell).
static func run_trace() -> String:
	var rt := EQRuntime.new()
	rt.emit_engine_diagnostics = false
	for item in STACK:
		rt.register_actor(item[0])
		rt.schedule(item[0], 1, int(item[1]), &"resolve")  # same tick, priority = depth

	var trace := EQTrace.new()
	var resolved := 0
	while true:
		var e := rt.advance()
		if e == null:
			break
		trace.record({"kind": "resolve", "item": String(e.actor_id), "depth": e.priority, "order": resolved})
		resolved += 1
	return trace.to_jsonl()


## The LIFO order as plain actor_ids (for the demo's sanity assertions).
static func resolution_order() -> Array:
	var rt := EQRuntime.new()
	rt.emit_engine_diagnostics = false
	for item in STACK:
		rt.register_actor(item[0])
		rt.schedule(item[0], 1, int(item[1]), &"resolve")
	var out: Array = []
	while true:
		var e := rt.advance()
		if e == null:
			break
		out.append(e.actor_id)
	return out


func _ready() -> void:
	print("[stack_resolution] LIFO order: ", resolution_order())
