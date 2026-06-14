# v0.1 MVP Milestone Evaluation (2026-06-15)

Scope evaluated: EQM-010 … EQM-034 (core scheduler, snapshot, trace harness, event-model semantics, Phase 2 resource/API, Phase 3 policy MVP + node + prediction + sample). Task: EQM-035. Method: audit the implemented surface against the reserved contracts, surface API friction, baseline product-value metrics, confirm the roadmap. Docs-only (no code changed).

Test state at evaluation: `./tools/test.sh` → PASS, `files=17 checks=234 failures=0`, `[api-surface] ok`. Godot 4.6.2 headless.

---

## 1. What v0.1 delivers

A working simple-path turn-order addon, headless and deterministic:

- **Core**: `EQScheduler` (push/pop/peek/cancel/reschedule) over a swappable `EQBackend`; lazy invalidation by generation; event-driven clock. Serializable `EQSnapshot` (schema_version + stable load error). Canonical JSONL trace with a golden gate and property tests (replay / permutation / snapshot-continuity).
- **Semantics**: the three-plane model and the seven reserved contract groups are documented (`EVENT_MODEL_SEMANTICS.md`), the coverage matrix maps 9 systems (`ORDERING_MODEL_COVERAGE.md`), and the open-questions registry is finalized.
- **Resource/API (Phase 2)**: `EQConfig`/`EQPolicy` with validation, the `EQError`/`EQValidation` taxonomy (`ERROR_CONTRACT.md`), actor/action API (`EQActorState`/`EQActionResult`/`EQActorRegistry`), the headless facade `EQRuntime` with dev/shipped resilience, and the layer-aware API surface gate (`check_api_surface.py` + golden).
- **Policy MVP + node (Phase 3)**: `EQFixedRoundPolicy`, `EQCTBPolicy`, the `EQManager` node (6 signals + driver contract), pure `EQPrediction`, and a learning-path CTB sample with a golden trace + quickstart.

---

## 2. Semantics drift audit (SEMANTICS vs implementation)

The rule (A1): contracts are reserved in Phase 1/2 and implemented in Phase 4/5+. "Reserved-but-unimplemented" is **not drift**; drift is implemented behaviour disagreeing with the spec.

| SEMANTICS section | status in v0.1 | drift? |
|---|---|---|
| §3 master timeline, int comparator, reschedule-only | implemented (EQEntry/EQOrdering/EQScheduler) | none |
| §4 event-line | reserved; dedicated policies use integer delays directly | none (A1; reducibility owed at EQM-053) |
| §5 solve/invalidation conditions | reserved (Phase 5/6) | none |
| §6 sweep point | reserved (Phase 6) | none |
| §7 composite comparator hook | reserved (Phase 5) | none |
| §8 reentrancy | reserved (Phase 6) | none |
| §10 save boundary (empty effect-chunk) | snapshot implemented (EQM-012); effect-chunk reserved (Phase 8) | none |
| §11 trace kinds | `resolved` implemented; other kinds reserved via the open schema (EQM-013) | none |
| §12 numeric int-only | implemented (ordering int; CTB delay integer ceil) | none |
| §13 actor_id no-reuse | implemented (EQM-021 registry) | none |
| §14 driver/await | implemented (EQManager, EQM-032) | none |
| §15 guardrails / §16 reservation boundary | respected; nothing frozen was broken | none |

**Conclusion: no drift.** The only tracked gap is that `EQCTBPolicy`/`EQFixedRoundPolicy` schedule via integer delays rather than the event-line primitive — explicitly permitted (independent policies, roadmap §1.1); the proof that they reduce to the event-line model is the existing EQM-053 task.

---

## 3. API friction findings

Each finding is classified `queue-candidate` or `no-change-for-v0.1` (with rationale).

| # | finding | classification |
|---|---|---|
| F1 | `EQActionResult` carries both `cost` and `delay`, but their meaning is policy-dependent (CTB uses `cost`; the no-policy default path uses `delay`; Fixed uses neither). A consumer can't tell from the type which field a policy honours. | **queue-candidate (doc)** → fold into EQM-100 manual: document per-policy `EQActionResult` semantics. No code change; not blocking. |
| F2 | `EQConfig.tie_break` validates but no current policy consumes it (Fixed uses initiative→sequence, CTB uses speed→sequence). A validated field with no behavioural effect yet. | **no-change-for-v0.1**: `tie_break` is a reserved contract that backs the API-surface totality story and future policies (e.g. equal-initiative options). Document its "reserved / policy-defined" status in EQM-100; revisit when a policy needs it (Phase 4 wait-turn tie-break is the likely first consumer). |
| F3 | Prediction is `EQPrediction.predict_turns(manager.runtime(), n)` — slightly verbose for HUD use. | **no-change-for-v0.1**: a `manager.predict()` convenience can be added by the HUD task (EQM-083) if it earns its surface cost; not adding it now keeps the EQManager surface minimal. |
| F4 | A policy reaches into `runtime.schedule(...)` inside `on_turn_finished` (the policy duck-types the runtime). Powerful but slightly under-typed. | **no-change-for-v0.1**: deliberate to avoid an EQRuntime↔EQPolicy class-name cycle; the contract is small and golden-gated. Revisit if a typed policy-context object is warranted in Phase 5. |

No blocking friction. All four are minor and either deferred to documentation (EQM-100) or to the task that would naturally own them.

---

## 4. North-star metrics (baseline)

| metric | baseline (v0.1) | how measured |
|---|---|---|
| simple-path completion without L3 | **achieved** — the CTB sample builds a full battle using only L0 (EQManager/EQRuntime/actor/action/prediction) + L1 (EQConfig/EQCTBPolicy); **0 L2/L3 symbols** touched | `demos/ctb_battle` + quickstart |
| layer-leak count | **0** | EQM-023 api-surface gate (`--self-test` + golden) every run |
| dogfood friction count | **0 blocking, 4 minor** (§3) | this evaluation |
| determinism coverage | core golden (`core_scheduler_basic`) + demo golden (`demo_ctb_battle`) + 5 property checks (replay/permutation/snapshot-continuity/decided_by/open-kind) | `./tools/test.sh` |
| resilience | dev/shipped two modes with proven mode-neutrality on normal input | EQM-022 tests |
| test breadth | 17 files / 234 checks / 0 failures | `./tools/test.sh` |
| public API size | 20 classes tagged by layer (core 10 / L0 6 / L1 4); L2/L3 empty (as planned) | `tests/golden/api_surface.json` |

These are the v0.1 baselines; later milestones track movement against them (especially layer-leak = 0 and simple-path-without-L3 staying true as L2/L3 grow).

---

## 5. Roadmap check

**Confirmed unchanged.** Phase 3 delivered the v0.1 MVP slice as specified (roadmap §225). Phase 4+ gates behind the v0.1 MVP contracts (roadmap §10); those contracts — core ordering, snapshot schema, error taxonomy, resilience modes, policy contract, layer gate — are now in place and green. No roadmap edit is required.

Queue adjustments from this evaluation: none structural. F1/F2 are recorded as documentation candidates folded into the existing EQM-100 (manual) task; no new tasks are created.

---

## 6. Verdict

**v0.1 MVP milestone met.** The simple turn-order path is usable, deterministic, layer-clean (no L3 leak), and resilient, with the deep-path contracts reserved without drift. The slice is ready to proceed to Phase 4 (energy / wait-turn policies) when directed.
