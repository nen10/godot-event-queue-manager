class_name EQWindow
extends RefCounted
## L2 first-class window (SEM §8.1, EQM-114): the "resolution interrupted for a
## decision" unit. The L0 await boundary (turn_ready -> suspend) is the implicit
## nest-0 window; explicit windows stack above it (LIFO) in
## EQReservationRuntime, which owns opening/closing, the meta-cost budget
## (Q02), and the deadline default (Q37).
##
## One window owns one draft (EQTransaction) — the transaction is the window's
## draft implementation (subordinate; the standalone EQTransaction API remains
## for compatibility). A frozen window is `deadline == DEADLINE_UNLIMITED`
## (the tick does not flow while the player thinks); a deadline window lets the
## tick flow and closes by default with a draft rollback at the deadline.

## Frozen window sentinel (deadline = ∞, SEM §9).
const DEADLINE_UNLIMITED := -1

var window_id: int = 0
var owner_actor: StringName = &""
## 0 is the implicit root (L0 await); explicit windows start at 1.
var nest_level: int = 0
## Acceptance tag; the base-operator level (Q01 save cap) is identified by kind.
var kind: StringName = &""
## Absolute global tick; DEADLINE_UNLIMITED = frozen.
var deadline: int = DEADLINE_UNLIMITED
## Meta-cost paid at open (Q02; not refunded within a chain).
var budget_paid: int = 0
## Intervention/meta ordering tag for this explicit window.
var meta_level: int = 0
## The window's draft (EQTransaction); null on the implicit root.
var draft = null
## Optional pre-close hook called when the deadline hits, BEFORE the default
## rollback+close — an explicit commit happens here or not at all (Q37; no
## silent default action). Transient (never serialized).
var pre_close: Callable = Callable()
var closed: bool = false
## Phase checkpoint stack for operation-phase sub-checkpoints (§8.4).
var phase_checkpoints: Array = []


func is_frozen() -> bool:
	return deadline == DEADLINE_UNLIMITED


func to_dict() -> Dictionary:
	var phases: Array = []
	for cp in phase_checkpoints:
		phases.append({
			"name": String(cp.get("name", "")),
			"seq": int(cp.get("seq", -1)),
		})
	return {
		"window_id": window_id,
		"owner_actor": String(owner_actor),
		"nest_level": nest_level,
		"kind": String(kind),
		"deadline": deadline,
		"budget_paid": budget_paid,
		"meta_level": meta_level,
		"phase_history": phases,
	}
