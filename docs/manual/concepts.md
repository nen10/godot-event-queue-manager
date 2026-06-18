# Concepts — the mental model

This chapter teaches the model the rest of the manual assumes. Read it once; the
**simple path (L0/L1) never needs the deep layers (L2/L3)**, but knowing why the
layers exist keeps a simple project simple.

Source of truth: `docs/design/EVENT_MODEL_CONCEPTS.md` and
`docs/design/EVENT_MODEL_SEMANTICS.md`. This is the consumer-facing summary.

---

## 1. The two questions

The addon answers two different questions; keep them separate.

| question | layer | you use |
|---|---|---|
| "Whose turn is next?" | **L0 / L1** | `EQManager`, an `EQConfig` + a policy |
| "What did this prepared/reacting/waiting action do, and in what order?" | **L2 / L3** | reservations, triggers, transactions, event-lines |

Most turn-based games only ever ask the first question. You can ship on L0/L1 and
never touch a reservation or an event-line.

---

## 2. The three planes (the deep model)

When you *do* go deep, the engine is built on three planes that never merge — that
non-merging is what makes the order deterministic and explainable.

```text
event-line ──(a condition's threshold is crossed)──▶ event becomes resolvable / invalid   (input → output)
event      ──(on resolve: issue / re-rate)─────────▶ event-line moves or is born            (output → input)
both       ──(record)──────────────────────────────▶ trace: event_line_progressed, …        (observation)
```

### 2.1 event-line — progression *input*

A named integer progression variable with an update rule (global tick is the
primary one; an entity's wait-time or charge can be others). It does not *happen*;
it only advances. It is never an item on the master timeline. Its job is to absorb
every game-specific "time passes / charge builds / fuel drains" as a coordinate
axis, so the resolution layer only ever sees "a condition's event-line crossed a
threshold."

### 2.2 event — ordered *output*

The unit of order resolution. When its `solve_conditions` (AND) are all met it
resolves: emits effects, may issue/re-rate event-lines, may schedule follow-up
events. If an `invalidation_condition` (OR) fires first, it drops without resolving.
A **reservation is an event plus an action-intent field.** The comparator orders
events by a single total key — `(due_tick ASC, priority DESC, sequence ASC)` — and
event-lines are kept out of this layer, so the total order stays provable.

### 2.3 event_line_progressed — *observation*

One line of the canonical trace ("at this point in the resolution stream, event-line
X advanced a→b / re-rated / was issued"). It is not a runtime object and causes
nothing: delete it and behavior is identical; only verifiability and explainability
change. This is why determinism can be golden-tested independently of the schedule.

---

## 3. The layering (L0 → L3)

```text
L0  turn order ("who acts next")     EQRuntime, EQManager, EQActorRegistry, EQPrediction
L1  policy selection                 EQConfig, EQFixedRoundPolicy, EQCTBPolicy, EQEnergyPolicy, EQWaitTurnPolicy
L2  reservation / prepared actions   EQActionDefinition, EQReservation, EQActionResolutionPolicy,
                                     EQTriggerEngine, EQCondition, EQTransaction
L3  event-line internals             (progression-as-input substrate; not surfaced as a user API)
```

Rules that protect the simple path:

- **L3 never leaks into an L0/L1 signature.** A class is assigned exactly one layer
  (`docs/design/API_SURFACE.md`); the api-surface gate fails the build if an L3 type
  appears in an L0/L1 public method. So a simple-path user cannot accidentally be
  handed an event-line.
- **L0/L1 are first-class on their own.** `EQManager` + `EQConfig` + a policy gives a
  complete, deterministic, save-able turn order with zero reservations.
- **L2 is opt-in.** You reach for reservations/triggers/transactions only when an
  action is *prepared, reacting, waiting, or operating on a target* (see
  `reservations.md`). L3 stays internal.

---

## 4. Where to go next

- Just ordering turns? You are done — see `EQManager` (L0) + a policy (L1). The
  Timeline Preview Dock projects exactly the order `EQPrediction` computes.
- Prepared / counter / wait / ready / target-operation actions? → `reservations.md`.
- The AP-recovery action-resolution loop + rollback/wait semantics? →
  `action_resolution.md`.
