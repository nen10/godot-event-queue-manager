# EQM-053 Self-Review 2026-06-15

Pattern: **P2 delegation** — authored by Codex 5.5 (gpt-5.5 xhigh, conservative execution under a tight contract); orchestrator (Opus) owned the contract and the gate. Repair: 1 orchestrator gate-repair (CTB carry semantics). Terminal Phase 5 task — its completion is the Phase 4/5 → Phase 5 milestone.

## Delegation record

- Contract: `docs/plan/2026-06-09_event_queue_manager/EQM-053_policy_reducibility_proofs/IMPLEMENTATION_PLAN.md` (tests-only; exact scope; conventions incl. the `:=`-on-untyped gotcha; gate = `./tools/test.sh` green + api-surface unchanged).
- Executor: `codex exec -s workspace-write` (gpt-5.5 xhigh, the user-authorized conservative executor; billed checkpoint waived per QUEUE_EXECUTION_PATTERNS §1.1).
- Codex stayed in scope: added only `test_project/tests/policy/test_eq_reducibility.gd` (no addons/tools/docs/golden changes; git diff confirmed). It self-verified green via a local-HOME workaround for a Godot sandbox log-path quirk in its environment.

## What it delivered (accepted as authored)

A genuine metamorphic equivalence proof: for each policy it (A) drives the dedicated policy through `EQRuntime` and (B) independently computes the order with a per-tick event-line simulation written in the test, then asserts A == B across speed/cost and tie-break matrices.

- **Energy** and **Wait-Turn**: correct and robust, including non-divisor speeds (17, 7) and equal-key tie-breaks (agility → registration order). Accepted unchanged. Energy correctly carries (matching its carry-over policy); wait-turn is a per-tick countdown.

## Orchestrator gate-repair (CTB carry semantics)

- **Finding**: the CTB per-tick sim *carried* charge (`charge -= threshold`), but the dedicated `EQCTBPolicy` is **no-carry** (reschedules at `ceil(cost*scale/speed)` from scratch). They coincide only when speed divides the threshold — and the delivered CTB cases used only divisor speeds (25/10/40/20), which **sidestepped** the divergence rather than surfacing it (contrary to the contract's "don't hide divergences", §1.1).
- **Repair** (orchestrator, in-context): reset the CTB sim's charge to 0 on acting (mirroring the no-carry policy) and added a **non-divisor-speed case** (30/7/13). The proof now holds **generally**, not just for cherry-picked speeds, and the carry/no-carry distinction (CTB no-carry vs Energy carry) is documented in the test.

## Acceptance result — met

| acceptance | result |
|---|---|
| CTB / energy / wait-turn via per-tick event-line reproduce the dedicated policies' order | A == B for all three across the matrices |
| across tie-break / speed / delay matrices | varying speeds (incl. non-divisor), varying costs, equal-key tie-breaks |
| per-tick polling ≡ optimized (closed-form) backend → identical traces | per-tick sim order == dedicated policy (closed-form delay) order |
| reduction not mandated; divergences recorded, not hidden | the CTB carry divergence was caught and resolved by aligning semantics (no-carry) + a general-case test, rather than hidden behind divisor speeds |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=25 checks=326 failures=0; [api-surface] ok
```

Tests-only; api-surface golden unchanged (no product/surface change).

## Deviations

- One file authored by an external executor (Codex 5.5), then gate-repaired by the orchestrator — this is the intended P2 flow (executor implements, orchestrator owns the gate and merges only after ACCEPT). The CTB repair demonstrates the value of the orchestrator-owns-the-gate model: the conservative executor produced a passing-but-incomplete proof, and the gate caught the hidden divergence.

## No sample-only completion

Direct metamorphic equivalence assertions against the live dedicated policies; no sample.

## Repair-now / follow-up

None. **Phase 5 (Action Reservation model) milestone reached** — reservation schema (EQM-050), pipeline (EQM-051), AP/ready model (EQM-052), and reducibility proofs (EQM-053) complete. The dedicated CTB/energy/wait policies are now proven to reduce to the per-tick event-line model. Next frontier is Phase 6 (EQM-060 condition/tag matching — the trigger/reaction engine).
