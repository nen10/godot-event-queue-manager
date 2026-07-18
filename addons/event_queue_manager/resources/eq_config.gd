class_name EQConfig
extends Resource
## Top-level configuration: which ordering policy and how ties are broken.
##
## The policy slot accepts exactly a concrete EQPolicy subclass — null and raw
## base instances are explicit validation errors, never a silent sample default
## (UX_PATH_REDUCTION: single-accepted-class + no-fallback-chain). tie_break must
## name a deterministic, total tie-break; unset is ambiguous, unknown is a
## contract violation. validate() only reports (EQValidation); acting on the
## result per dev/shipped mode is EQM-022's job.

const _EQPolicyScript := preload("policies/eq_policy.gd")

## Deterministic, total tie-breaks. sequence (insertion order) is always total;
## actor_id is total when ids are unique (the registry guarantees this, EQM-021).
const TIE_BREAKS: Array[StringName] = [&"sequence", &"actor_id"]

## Scheduler storage backend (EQM-145). SORTED_ARRAY is the compatibility default
## and the value old .tres files load as (a missing field defaults to 0). Both
## backends honour EQBackend and produce an identical pop sequence/trace because
## EQOrdering is total; BINARY_HEAP trades O(n) insert/pop for O(log n) on large
## queues. Only opt into the heap after EQM-142 live-peek (avoids a per-resolution
## full sort). Backend is chosen at scheduler setup, not serialized in the
## scheduler snapshot, so a save is portable across backends.
enum SchedulerBackend { SORTED_ARRAY = 0, BINARY_HEAP = 1 }

@export var policy: EQPolicy
@export var tie_break: StringName = &"sequence"
@export var scheduler_backend: SchedulerBackend = SchedulerBackend.SORTED_ARRAY
@export var schema_version: int = 1


## Reports config issues as an EQValidation (no side effects, deterministic).
func validate() -> EQValidation:
	var v := EQValidation.new()
	if policy == null:
		v.add(EQError.POLICY_MISSING, "EQConfig.policy is not set")
	elif policy.get_script() == _EQPolicyScript:
		v.add(EQError.POLICY_BASE_INSTANCE, "policy is a raw EQPolicy base instance; assign a concrete subclass")
	if tie_break == &"":
		v.add(EQError.TIE_BREAK_AMBIGUOUS, "tie_break is unset; choose a deterministic total tie-break")
	elif not TIE_BREAKS.has(tie_break):
		v.add(EQError.TIE_BREAK_UNKNOWN, "unknown tie_break: %s" % String(tie_break))
	if scheduler_backend != SchedulerBackend.SORTED_ARRAY and scheduler_backend != SchedulerBackend.BINARY_HEAP:
		v.add(EQError.CONFIG_SCHEDULER_BACKEND_UNKNOWN, "unknown scheduler_backend: %d" % int(scheduler_backend))
	return v
