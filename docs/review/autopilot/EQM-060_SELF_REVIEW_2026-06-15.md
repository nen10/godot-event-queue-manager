# EQM-060 Self-Review 2026-06-15

Pattern: **P2 delegation** — Codex 5.5 (gpt-5.5 xhigh) implemented an orchestrator-pinned contract; orchestrator owned the contract, the API-surface wiring, and the gate. Repair: 0 (accepted as authored; orchestrator added house-style class docs only).

## Delegation record

- Contract: `EQM-060_condition_contract/IMPLEMENTATION_PLAN.md` — the EQCondition field shape + matching semantics + EQTagMatcher behavior + test list were **fully pinned by the orchestrator** (no design left to the executor → no design shrink), with the api-surface caveat (executor must not touch tools/golden; orchestrator wires the surface).
- Executor: `codex exec -s workspace-write` (gpt-5.5). Stayed in scope: added only `eq_condition.gd`, `eq_tag_matcher.gd`, and `tests/trigger/{test_eq_condition,test_eq_tag_matcher}.gd`; did not touch tools/golden; removed stray `.uid` sidecars. It correctly anticipated the expected api-surface failure for the two new classes and reported the Godot suite green.

## Orchestrator review + merge

- Verified both files match the pinned contract exactly: EQTagMatcher.has_all/has_any with the empty-constraint identity; EQCondition.matches() as the AND of kind/source/target/require_tags/any_tags/custom_predicate, with `sensing_required` an unevaluated placeholder and `custom_predicate` transient. No extra fields, no shrink.
- Polish (orchestrator): added concise `##` class docs to match house style (no behavior change).
- Wired the API surface: `EQCondition: L2`, `EQTagMatcher: L2` in LAYER_MAP + API_SURFACE.md; re-baselined the golden via `--update`.

## Changed files

- `addons/event_queue_manager/resources/eq_condition.gd`, `addons/event_queue_manager/runtime/eq_tag_matcher.gd` (new; Codex-authored + orchestrator docs).
- `tools/check_api_surface.py` + `docs/design/API_SURFACE.md` + `tests/golden/api_surface.json` (orchestrator surface wiring).
- `test_project/tests/trigger/test_eq_condition.gd`, `test_eq_tag_matcher.gd` (new; Codex-authored).

## Acceptance result — met

| acceptance | result |
|---|---|
| match event type | `match_kind` exact match (wildcard when empty) |
| match source | `match_source` against view source |
| match target | `match_target` against view target |
| match tags | `require_tags` (all, via has_all) + `any_tags` (any, via has_any) |
| range/sensing adapter placeholder | `sensing_required` reserved, not evaluated (documented placeholder) |
| custom predicate | transient `custom_predicate: Callable`, called when valid |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=27 checks=344 failures=0; [api-surface] ok
```

L2 surface now includes EQCondition + EQTagMatcher; no L3 leak into L0/L1.

## UX path reduction

- Added: `EQCondition`/`EQTagMatcher` (L2, opt-in). Narrowed: matching against a normalized view (decoupled from EQEntry/EQReservation); custom_predicate is transient (serializable core preserved). Residual: none.

## Deviations

- Class docs added post-delivery (orchestrator, house style) — no behavior change. Surface wiring done by orchestrator per the contract (executor was scoped out of tools/golden).

## No sample-only completion

Direct matching assertions across all dimensions; no sample.

## Repair-now / follow-up

None. Next: EQM-061 (reaction preparation runtime) — the trigger engine that, at the sweep point after each resolution, matches armed reaction preparations (via EQCondition) against the resolving event and fires/expires them. Kept orchestrator-direct (design core).
