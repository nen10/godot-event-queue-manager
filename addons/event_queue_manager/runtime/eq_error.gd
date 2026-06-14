class_name EQError
extends RefCounted
## Error taxonomy: the single authority for stable error codes, their
## recoverability class, severity, and where they surface.
##
## Codes are namespaced StringNames (`eqm.<area>.<name>`) and are APPEND-ONLY:
## a code is never repurposed or removed, so it stays stable across versions and
## byte-safe in the canonical trace. Each code maps to a recoverability class
## (RUNTIME_RESILIENCE_POLICY §1), which dictates the dev/shipped behaviour —
## but acting on it (dev assert vs shipped skip) is the resilience mode toggle's
## job (EQM-022), not this taxonomy's. Validation only reports (EQValidation).
##
## Full table and the recoverability → dev/shipped mapping: docs/design/ERROR_CONTRACT.md.

## Recoverability classes — mirror RUNTIME_RESILIENCE_POLICY §1 exactly.
enum Recoverability {
	CONTRACT_VIOLATION,  ## dead-actor reservation, unknown schema_version, invalid base_type
	BUDGET_EXCEEDED,     ## reentrancy depth / reaction-chain limit
	RESOURCE_INVALID,    ## missing policy, ambiguous tie-breaker
	EXTERNAL_STATE,      ## actor node freed, WeakRef expired
}

enum Severity { WARNING, ERROR }

# --- stable codes (append-only) ------------------------------------------
const POLICY_MISSING := &"eqm.config.policy_missing"
const POLICY_BASE_INSTANCE := &"eqm.config.policy_base_instance"
const TIE_BREAK_AMBIGUOUS := &"eqm.config.tie_break_ambiguous"
const TIE_BREAK_UNKNOWN := &"eqm.config.tie_break_unknown"
const POLICY_NAME_EMPTY := &"eqm.policy.name_empty"
const ACTOR_DUPLICATE_ID := &"eqm.actor.duplicate_id"
const ACTOR_ID_REUSED := &"eqm.actor.id_reused"
const ACTOR_EMPTY_ID := &"eqm.actor.empty_id"
const ACTION_NEGATIVE_DELAY := &"eqm.action.negative_delay"
const ACTION_NEGATIVE_COST := &"eqm.action.negative_cost"
const RUNTIME_UNREGISTERED_ACTOR_EVENT := &"eqm.runtime.unregistered_actor_event"
const RUNTIME_SCHEDULE_UNREGISTERED_ACTOR := &"eqm.runtime.schedule_unregistered_actor"

# code -> {rec, sev, surface}. surface is a subset of ["editor", "game"].
const _META := {
	POLICY_MISSING: {"rec": Recoverability.RESOURCE_INVALID, "sev": Severity.ERROR, "surface": ["editor", "game"]},
	POLICY_BASE_INSTANCE: {"rec": Recoverability.CONTRACT_VIOLATION, "sev": Severity.ERROR, "surface": ["editor", "game"]},
	TIE_BREAK_AMBIGUOUS: {"rec": Recoverability.RESOURCE_INVALID, "sev": Severity.ERROR, "surface": ["editor", "game"]},
	TIE_BREAK_UNKNOWN: {"rec": Recoverability.CONTRACT_VIOLATION, "sev": Severity.ERROR, "surface": ["editor", "game"]},
	POLICY_NAME_EMPTY: {"rec": Recoverability.RESOURCE_INVALID, "sev": Severity.WARNING, "surface": ["editor"]},
	ACTOR_DUPLICATE_ID: {"rec": Recoverability.CONTRACT_VIOLATION, "sev": Severity.ERROR, "surface": ["editor", "game"]},
	ACTOR_ID_REUSED: {"rec": Recoverability.CONTRACT_VIOLATION, "sev": Severity.ERROR, "surface": ["editor", "game"]},
	ACTOR_EMPTY_ID: {"rec": Recoverability.RESOURCE_INVALID, "sev": Severity.ERROR, "surface": ["editor", "game"]},
	ACTION_NEGATIVE_DELAY: {"rec": Recoverability.CONTRACT_VIOLATION, "sev": Severity.ERROR, "surface": ["editor", "game"]},
	ACTION_NEGATIVE_COST: {"rec": Recoverability.RESOURCE_INVALID, "sev": Severity.ERROR, "surface": ["editor", "game"]},
	RUNTIME_UNREGISTERED_ACTOR_EVENT: {"rec": Recoverability.CONTRACT_VIOLATION, "sev": Severity.ERROR, "surface": ["editor", "game"]},
	RUNTIME_SCHEDULE_UNREGISTERED_ACTOR: {"rec": Recoverability.CONTRACT_VIOLATION, "sev": Severity.ERROR, "surface": ["editor", "game"]},
}


static func is_known(code: StringName) -> bool:
	return _META.has(code)


## Recoverability of a code. An unknown code defaults to the strictest class
## (CONTRACT_VIOLATION) so it can never be silently downgraded (fail-safe).
static func recoverability_of(code: StringName) -> int:
	if _META.has(code):
		return _META[code]["rec"]
	return Recoverability.CONTRACT_VIOLATION


## Severity of a code. An unknown code defaults to ERROR (never silently a warning).
static func severity_of(code: StringName) -> int:
	if _META.has(code):
		return _META[code]["sev"]
	return Severity.ERROR


## Whether a code surfaces in the given context ("editor" / "game").
static func surfaces_in(code: StringName, where: String) -> bool:
	if _META.has(code):
		return where in (_META[code]["surface"] as Array)
	# unknown code: surface everywhere rather than hide it
	return true
