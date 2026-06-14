class_name EQPolicy
extends Resource
## Base extension point for ordering policies (Fixed round / CTB / Energy /
## Wait-Turn / Action-Resolution, delivered Phase 3+).
##
## This base is an EXTENSION POINT (UX_PATH_REDUCTION §4), not a usable policy:
## a concrete subclass defines the actual ordering rule. A raw base instance
## assigned to EQConfig.policy is a contract violation (EQConfig.validate flags
## POLICY_BASE_INSTANCE) — the slot accepts exactly one class family, the
## concrete subclass, with no "works for now" base fallback.

## Human-facing identifier for editor/debug surfaces; not an ordering key.
@export var policy_name: StringName = &""


## Policy contract (overridden by concrete subclasses). A policy expresses an
## ordering rule purely through the runtime's L0 primitives — registry,
## scheduler.current_tick, and runtime.schedule(...) — never by reaching into
## the scheduler backend. The same two hooks carry Fixed/CTB/Energy/Wait/AP.
##
## `runtime` and `result` are left untyped here to avoid a class-name cycle
## (EQRuntime → EQConfig → EQPolicy); concrete policies duck-type the calls.

## Schedules the initial turns for the given actor ids (battle start).
func seed(_runtime, _actor_ids: Array) -> void:
	pass


## Schedules the actor's next turn after it finishes an action.
func on_turn_finished(_runtime, _actor_id: StringName, _result) -> void:
	pass
