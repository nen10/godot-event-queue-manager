# Dogfood Friction Report — Action Resolution slice (2026-06-18)

Source: `dogfood/action_resolution/battle.gd` (EQM-084). A minimal playable Action Resolution Turn-Based slice built with the **public API only**, exercising AP turns, a counter reaction, effect/presentation records, and deterministic RNG, proven by a golden trace.

Method: build the slice; record every point of API friction encountered; classify each as a **queue-candidate** (with a target task) or **no-change** (with rationale). The slice needed **no runtime internals** — the public surface was sufficient.

---

## Findings

| # | finding | classification |
|---|---|---|
| F1 | **Two turn-close paths are easy to confuse.** `EQManager.step()` suspends on `turn_ready` (`_awaiting_turn`), cleared only by `EQManager.finish_action`. But `EQActionResolutionPolicy.wait_close` drives the runtime directly and does **not** clear the manager's suspend — so a manager-driven loop that calls `wait_close` deadlocks after one turn (hit during this dogfood). The manager-driven loop must use `finish_action`; `wait_close` is for the explicit-transaction flow where you drive the runtime yourself. | **queue-candidate (doc + small API)** → EQM-100 manual: document the two flows explicitly. Optional polish: have `wait_close` accept/clear a manager's suspend, or expose `manager.wait_close(tx)`. Not blocking; recorded. |
| F2 | **Effect + presentation production is fully manual.** Per action the consumer creates an `EQEffectRecord`, adds it to the chunk, records it to the trace, enqueues an `EQPresentationEvent`, and drives the trigger sweep. No manager hook bundles "on resolution → effect/visual/sweep". | **no-change-for-v1** (correct boundary: the addon cannot know a game's effect semantics) + **candidate** → EQM-085 node bridge may wire effect/presentation/trigger **signals** so a consumer can subscribe instead of hand-driving; EQM-100 documents the manual pattern. |
| F3 | **The trigger sweep is consumer-driven.** `EQTriggerEngine.on_event_resolved(view, tick)` must be called by the consumer at the sweep point; it is not integrated into `EQManager.advance`. | **no-change-for-v1**: the sweep timing is intentionally the consumer's (it depends on the game's resolution model). EQM-100 documents the sweep-point call site. |
| F4 | **The combined runtime trace is hand-assembled.** The consumer composes one `EQTrace` with `turn` / `effect` / `reaction_fired` kinds (the open-kind schema). | **no-change**: the open-kind trace schema is the contract; composing the runtime trace is the consumer's choice. Works as designed (deterministic golden achieved). |

## Positive observations

- **Public-API-sufficient**: no `runtime`-internal access was needed; the slice imports only public classes.
- **Layering held**: L0/L1 for turns, L2 for reservations/triggers/transaction, `presentation` for effects/visuals, `core` for RNG/trace — no cross-layer leak, and the simple turn loop never had to touch L2 to function.
- **Determinism**: a seeded `EQRng` damage roll + the scheduler produced a byte-stable golden trace.

## Net

0 blocking. F1 is the one genuine ergonomics sharp edge (caught and worked around in the slice); it folds into EQM-100 (doc) with an optional small API polish. F2/F3 are correct boundaries with a documentation + (optional) EQM-085 signal-wiring follow-up. No new tasks are forced; the candidates attach to existing EQM-100 / EQM-085.
