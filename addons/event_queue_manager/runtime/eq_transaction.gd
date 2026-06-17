class_name EQTransaction
extends RefCounted
## Player-turn draft transaction over a scheduler (PROJECT_PROFILE: transactional
## player turns — rollback before wait/end-turn is first-class).
##
## Working-copy model: at begin, the live scheduler's snapshot is saved (`_base`)
## and a working clone is restored from it. Draft operations touch only the
## working copy, so the live scheduler is unchanged until commit. rollback resets
## the working copy to base; commit promotes the working copy to live. Built on
## the EQM-012 snapshot/restore + EQM-033 EQSnapshot.equals.
##
## Wait/end-turn commit + scheduling the ready reservation is EQM-071;
## deterministic replay is EQM-072.

const EQScheduler := preload("eq_scheduler.gd")
const EQSnapshot := preload("eq_snapshot.gd")

var _live: EQScheduler
var _base: Dictionary
var _working: EQScheduler
var _committed: bool = false
var _draft_log: Array[Dictionary] = []


func _init(live: EQScheduler) -> void:
	_live = live
	_base = live.snapshot()
	_working = EQScheduler.new()
	_working.restore(_base)


## The draft scheduler (inspect the would-be state).
func working() -> EQScheduler:
	return _working


## The recorded draft operations (for inspection / UI).
func draft() -> Array:
	return _draft_log.duplicate(true)


## True while the live scheduler still equals its pre-draft snapshot (i.e. before
## commit). Drafting never touches live.
func is_live_unchanged() -> bool:
	return EQSnapshot.equals(_live.snapshot(), _base)


func is_committed() -> bool:
	return _committed


## Drafts a push onto the working copy. Returns the working event_id (or -1).
func draft_push(due_tick: int, priority: int = 0, kind: StringName = &"", actor_id: StringName = &"") -> int:
	var id := _working.push(due_tick, priority, kind, actor_id)
	if id != -1:
		_draft_log.append({"op": &"push", "event_id": id, "due_tick": due_tick, "kind": String(kind), "actor_id": String(actor_id)})
	return id


## Drafts a cancel onto the working copy.
func draft_cancel(event_id: int) -> bool:
	var ok := _working.cancel(event_id)
	if ok:
		_draft_log.append({"op": &"cancel", "event_id": event_id})
	return ok


## Discards the draft: the working copy returns to the pre-draft state. Live is
## (and remains) unchanged.
func rollback() -> void:
	_working.restore(_base)
	_draft_log.clear()


## Promotes the draft to the live scheduler. After this, live == the working copy.
func commit() -> void:
	_live.restore(_working.snapshot())
	_committed = true
