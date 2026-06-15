# EQM-053 IMPLEMENTATION_PLAN — Contract (delegated to Codex 5.5, gate by orchestrator)

## Scope (tests-only)

ADD test files only. **Do NOT modify** `addons/`, `tools/`, `docs/`, the queue, or any golden via `--update-golden`. No new public class / no API-surface change.

- `test_project/tests/policy/test_eq_reducibility.gd` (new) — the reducibility proofs.
- (optional) `test_project/tests/golden/` reducibility golden(s) only if a stored reference is needed; prefer comparing live dedicated-policy output (no golden file required).

## Acceptance

For CTB, energy, and wait-turn, a per-tick event-line simulation reproduces the dedicated policy's resolved-turn order (metamorphic equivalence), across a speed / cost / tie-break matrix:

- **CTB** (`EQCTBPolicy`): per-tick CT += speed; ready when CT >= base_cost*scale; carry remainder. Resolved actor order over N turns == the dedicated policy's order.
- **Energy** (`EQEnergyPolicy`): per-tick energy += speed; ready at threshold; carry remainder. Order matches.
- **Wait-turn** (`EQWaitTurnPolicy`): per-tick wait countdown; ready at 0; next wait = action cost; equal wait broken by agility then registration order. Order matches.

This proves per-tick polling (Q17) ≡ the dedicated policy's closed-form scheduling. Reducibility shows generality; it does not mandate reduction (roadmap §1.1) — any genuine divergence must be asserted/recorded as a model gap rather than hidden.

## Conventions (must follow — these are how the suite works)

- Test file: `extends RefCounted`; `static func run(t) -> void:`; assertions via `t.ok(cond, msg)` / `t.eq(actual, expected, msg)`.
- Reference classes by `preload("res://addons/event_queue_manager/...")` (path load), not global names.
- Drive a dedicated policy via `EQRuntime` (`runtime/eq_runtime.gd`) + `EQActionResult` + the policy's `seed` / `on_turn_finished` (see `tests/policy/test_eq_ctb_policy.gd` etc.).
- **GDScript gotcha (important):** never use `:=` when the right-hand side comes from an untyped value (e.g. an element of an untyped `Array`); write `var x: int = ...`. The test runner fails the whole suite on a parse error.
- Determinism: integer only; no float in ordering. Same inputs → same order.

## Gate (orchestrator owns)

- `./tools/test.sh` is green (`[run_all] ... failures=0`, `[api-surface] ok`, exit 0). The api-surface golden must be UNCHANGED (tests-only ⇒ no surface change).
- Orchestrator reviews the diff: only the new test file(s) under `test_project/tests/`. Any out-of-scope change is reverted.

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| EQCTBPolicy/EQEnergyPolicy/EQWaitTurnPolicy | sim ≠ policy | per-tick sim order == dedicated policy order |
| Q17 (per-tick ≡ optimized) | divergence | matrix equivalence across speed/cost/tie |
| §1.1 (reduction not mandated) | hidden gap | divergences asserted/recorded, not hidden |
| DETERMINISM | non-deterministic sim | integer-only; repeated runs identical |

## Completion checklist

- [ ] CTB / energy / wait-turn each: per-tick sim order == dedicated policy order.
- [ ] speed / cost / tie-break matrix covered.
- [ ] tests-only; api-surface golden unchanged; `./tools/test.sh` PASS.
