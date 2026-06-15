# EQM-052 Self-Review 2026-06-15

Pattern: P0 (orchestrator-direct — the design core, kept in-house per the Phase-5 design-shrink caution). Repair: 1 (test-only type annotation; no product change).

## Execution summary

Implemented `EQActionResolutionPolicy`, the Action Resolution Turn-Based policy (the roadmap's core test case). A turn is a ready reservation granted when an actor's AP has recovered: the resolution time "N" means "until AP recovers by N." AP spend/recovery is integer and deterministic (`ready delay = ceil(spent_AP / recovery)`); the turn closes through wait (`on_turn_finished`), which schedules the next ready reservation. `ready_reservation_for` exposes the next turn as a concrete EQM-050 READY reservation.

## Changed files

- `addons/event_queue_manager/resources/policies/eq_action_resolution_policy.gd` — `EQActionResolutionPolicy` (L2): ap_key/recovery_key/ap_max/recovery_per_tick/action_ap_cost; seed/on_turn_finished/ready_reservation_for.
- `tools/check_api_surface.py` + `docs/design/API_SURFACE.md` — `EQActionResolutionPolicy: L2`.
- `tests/golden/api_surface.json` — re-baselined (explicit `--update`).
- `test_project/tests/policy/test_eq_action_resolution_policy.gd`.

## Acceptance result — met

| acceptance | result |
|---|---|
| ready reservation grants turn after AP recovery delay | seed → first ready at ceil(ap_max/recovery)=10; after a turn, next ready at ceil(spent/recovery) |
| AP spending and recovery are deterministic | `data["ap"]` = ap_max − spent after a turn; identical inputs reproduce the same delay |
| turn closes through wait | `on_turn_finished` (the wait close) schedules exactly one next ready; a cheaper wait (cost 30) → sooner (ceil(30/10)=3), AP 70 |

Plus: `ready_reservation_for` returns a READY reservation whose delay is the AP-recovery time.

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=24 checks=319 failures=0; [api-surface] ok
```

## Repair record (gate REJECT → fix, attempt 1/3)

- Symptom: `var before := <untyped rt>.scheduler.size()` could not infer (rt came from an untyped Array element). Caught by the masked-failure guard.
- Fix: `var before: int = …`. Test-only.

## API surface change (explicit golden re-baseline)

`--update`. Diff: L2 gains `EQActionResolutionPolicy`. No L3 leak (an L2 policy returning an L2 reservation is same-layer; the gate confirms no L3 in L0/L1).

## Design notes (no shrink)

- **AP recovery is the progression**; the ready delay `ceil(spent/recovery)` is exactly "resolution time = until AP recovers by N." The structural kinship with the energy policy is intentional and is what EQM-053 will prove (all dedicated policies reduce to the reservation + event-line model).
- **`EQActionResolutionPolicy` is L2** (deep AP/reservation path) while its base `EQPolicy` stays L1 — the simple policies (Fixed/CTB/Energy/Wait) remain L1; only the Action Resolution policy crosses into L2.
- **`ready_reservation_for`** ties the AP timing to the EQM-050 READY reservation kind, making "ready reservation" a concrete object, not just a scheduled turn.
- Full event-line backend and solve-condition objects are deferred (EQM-053 reducibility / EQM-060 conditions) — this task is the AP/ready/wait model.

## UX path reduction

- Added: `EQActionResolutionPolicy` (L2). Narrowed: AP/recovery from `data`; `cost<=0 → action_ap_cost`; recovery clamped ≥1. Residual: none.

## Deviations

- None beyond the planned surface addition.

## Repair-now / follow-up

None. Next: EQM-053 (policy reducibility proofs) — express CTB / energy / wait-turn via the reservation + event-line model and reproduce the dedicated policies' golden traces. This is a faithful-reproduction task (fixed target = existing goldens), the low-design-shrink-risk candidate the user authorized for the conservative Codex 5.5 executor; I will decide delegate-vs-direct at that task with the model in front of me.
