# EQM-100 Self-Review 2026-06-18

Pattern: P0 (orchestrator-direct — manual = design-adjacent docs). Repair: 0. Docs-only.

## Execution summary

Wrote the consumer manual: a concepts chapter (three-plane model + L0→L3 layering)
and the reservation / action-resolution references. Every cited class, method, enum,
and constructor was checked against the live source before writing; the dogfood-F1
friction (finish_action vs wait_close) is documented as the §2.1 warning it warranted.

## Changed files

- `docs/manual/concepts.md`, `docs/manual/reservations.md`, `docs/manual/action_resolution.md` (new).

## Acceptance result — met

| acceptance | result |
|---|---|
| manual matches current API | every signature verified against source: `EQManager.step/finish_action`, `EQActionResult.new(cost, delay)`, the 6 `EQActionDefinition.Kind`s, `EQReservation.Status`, `EQTriggerEngine.arm/on_event_resolved`, `EQActionResolutionPolicy.ap_max/recovery_key/ready_reservation_for/wait_close`, `EQTransaction.new(live)/draft_push/commit/rollback/is_live_unchanged` |
| examples avoid sample-only assumptions | all snippets use the public API directly (register real actors, concrete policy); the canonical worked example is `demos/action_resolution/demo_battle.gd` (public-API-only), not a sample resource |
| rollback / wait / ready semantics documented | §3 wait/ready/end-turn (WAIT schedules READY; commit at the wait/end-turn boundary, EQM-071); §4 EQTransaction working-copy commit/rollback (live byte-identical on rollback) |
| concepts chapter teaches the three-plane model + L0→L3 so simple-path users never need L3 | concepts.md §2 (event-line/event/event_line_progressed, one-way valves) + §3 (layering + the api-surface L3-leak guarantee) + §1 ("the two questions": L0/L1 ships without reservations) |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=42 checks=626 failures=0; [api-surface] ok
```

Docs-only: check count unchanged.

## Design notes (no shrink)

- **API-accurate, not aspirational.** I grepped each class for its real signatures
  (`EQTransaction.new(live: EQScheduler)`, `EQActionResult.new(p_cost, p_delay)`, the
  `Kind` enum) and wrote against those, so the manual cannot drift from the code on
  day one.
- **The simple path is protected in prose AND in the gate.** concepts.md states the
  L3-into-L0/L1 leak rule and ties it to the api-surface gate — the promise "simple
  users never need L3" is one the build actually enforces, not a hope.
- **F1 folded where it belongs.** The finish_action vs wait_close deadlock is the
  exact thing a consumer hits first; it is a boxed warning in the action-resolution
  chapter, with the manager-driven vs explicit-transaction split spelled out.
- **The demo is the worked example.** Both reference chapters point at
  `demo_battle.gd` (the EQM-092 public-API demo) rather than inventing throwaway
  snippets — one canonical, runnable, deterministic example.

## UX path reduction

- No code. The manual narrows the user's path: it names the two questions, routes
  L0/L1 users away from L2/L3, and gives one canonical example. Residual: an
  event-line (L3) user chapter is intentionally absent — L3 is not a surfaced API yet.

## Deviations

- None. Docs-only, scoped to the three named files.

## Repair-now / follow-up

None. Next: EQM-101 (demo suite — runnable demos across policies). Orchestrator-direct
or Codex-delegable (clear, contract-pinned). Per the run-to-end rule I will assess at
start.
