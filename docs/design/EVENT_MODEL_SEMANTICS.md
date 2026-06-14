# Event Model Semantics (v1)

status: authoritative for v1 (EQM-014.01, 2026-06-15). This is the semantics that Phase 2/5 build on.

Inputs (confirmed):

- `docs/design/EVENT_MODEL_CONCEPTS.md` — the three-plane model (confirmed 2026-06-14).
- `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` — Q01–Q26 decision registry.
- `docs/review/EVENT_MODEL_OPEN_QUESTIONS_SYNTHESIS_2026-06-14.md` — decision rationale.
- Implemented core: EQEntry/EQOrdering (EQM-010), scheduler (EQM-011), snapshot schema (EQM-012), open trace-kind schema (EQM-013).

Reservation boundary: this document **reserves contracts, schema field names, and trace record kinds in Phase 1/2**. The backend/runtime implementation of event-line progression, conditions, reservations, triggers, and presentation is delivered in Phase 4/5+, and **must not require a backward-incompatible change to anything frozen here** (§16).

---

## 1. Scope

Defines, for v1: how progression is expressed (event-line), how an event resolves or is invalidated, how "simultaneous" events are ordered, how reactions/windows nest without runaway, when a save is allowed, what the canonical trace records, and the developer-facing layering (L0–L3). It does **not** define any specific policy's rules (Fixed/CTB/Energy/Wait-Turn/Action-Resolution live in Phase 3–5) nor presentation behaviour (Phase 8); it gives those the contracts they attach to.

---

## 2. Three-plane model and L0–L3 layering

### 2.1 The three planes (recap; authoritative)

`event-line`, `event`, and `event_line_progressed` are **not three forms of one thing** — they live on three different planes. Keeping them separate is what makes determinism provable. (Full discussion: `EVENT_MODEL_CONCEPTS.md`.)

| plane | role | on master timeline? | causes anything? |
|---|---|---|---|
| **event-line** | progression **input / state** — a named integer progression variable whose update rule (increment, condition) is acceptance-defined | no | no — it only advances |
| **event** | ordering **output** — the unit of resolution; resolves when `solve_conditions` (AND) hold, drops when `invalidation_conditions` (OR) hold | yes (the only thing that does) | yes — emits effects, issues/re-rates event-lines, schedules events |
| **event_line_progressed** | **observation / record** — a canonical-trace line noting an event-line advanced | no | no — removing it changes only verifiability |

One-way valves connect them (input → output → input), and **a moving coordinate never becomes an item on the timeline**:

```text
event-line crosses threshold ──(condition holds)──▶ event becomes resolvable / invalidated   (input → output)
event resolves               ──(issue / re-rate)──▶ event-line advances / is created          (output → input)
both                         ──(record)───────────▶ trace: event_line_progressed, etc.        (observation)
```

### 2.2 Layering L0–L3 (roadmap §3.1)

The public surface is layered so a simple-path user never meets deep machinery:

| layer | surface | a user here works with |
|---|---|---|
| **L0** turn order | "who acts next" | actors + a policy; pop the next turn |
| **L1** policy | swap ordering rule | Fixed / CTB / Energy / Wait-Turn presets |
| **L2** reservation / event-line | prepared actions, delays, reactions | reservations, conditions, event-lines |
| **L3** event-line internals | issuance, race patterns, comparator hooks, reentrancy budgets | the contracts in this document |

**Invariant: L3 concepts must not leak into the L0/L1 surface.** A user choosing "CTB with these speeds" never has to name an event-line, a race-group, or a comparator hook. L2/L3 are opt-in. EQM-023 (API surface gate) enforces non-leakage mechanically.

---

## 3. Master timeline and ordering

- The master timeline is a **single deterministic total order over events**, decided by the int comparator `(due_tick ASC, priority DESC, sequence ASC)` (EQOrdering, EQM-010). This is the only ordering authority.
- Ordering keys are **immutable after an entry is created** (Q08). The only way to change an event's position is **reschedule = cancel + re-push** with a fresh sequence and a bumped generation (Q07). **Direct `due_tick` rewrite is forbidden.**
- `sequence` is unique per push, so the order is total: no two distinct entries compare equal, and the result is independent of sort stability.
- Float never participates in this comparator (§12).

This section is already implemented (EQM-010/011); it is restated because every other contract here is defined **relative to it** — event-lines feed it, conditions gate entry onto it, comparators extend only *within* a composite, never replace it.

---

## 4. Event-line (Q07/Q13/Q16/Q17/Q26)

### 4.1 Definition

An **event-line** is a named integer progression value attached to some unit (global / party / entity / any acceptance-defined group). Its update rule (increment amount, advance condition) is acceptance-defined. It is progression **input**: it never lands on the master timeline; it only advances and is *read* by conditions.

- **`global tick` is the primary event-line** — one distinguished instance. Other event-lines are acceptance-defined.
- **Event-side issuance is allowed**: a resolving event may create a new event-line or re-rate an existing one. (Issuance order is unique — parallel issuance is forbidden, §7 — so id assignment is deterministic across replay.)
- **Per-entity event-line is NOT a built-in required field.** Whether each entity has its own WT/CT event-line is acceptance-defined. Forcing a built-in per-entity field would fix one behaviour for a primitive whose whole point is to absorb game-specific progression. (Q16 decision.)

### 4.2 Two representations of progression (the scaling key — Q26 / CONCEPTS §3.1)

The same "progression" can be expressed two ways; the choice sets cost:

| representation | what happens | use when | event-line count |
|---|---|---|---|
| (1) **first-class event-line** | own identity, a snapshot entry, directly polled | a *few independent* axes (shared party WT, a global weather counter) | = number of axes |
| (2) **entity/effect state + tick-driven sweep** | value lives as an entity/effect field; one system event on the primary tick advances many homogeneous values at once and issues a resolution event on threshold | *many homogeneous* progressions (every entity's CT, every buff's uses_left) | O(1) |

**Homogeneous** = the *shape* of the progression rule is identical and only per-entity parameters differ. Mechanical test: the rule separates into a shared callable + per-entity params. If so, use (2) (default for many same-rule progressions, keeping first-class event-line count independent of entity count). Use (1) only for axes whose rules are individually distinct.

### 4.3 Watched / sparse polling

An event-line is **watched** when at least one pending event's solve/invalidation condition references it. This is a state-derived property (from current pending conditions), independent of prediction depth. **Polling advances only event-lines that are watched and non-frozen (rate ≠ 0).** So advance cost scales with axes actually monitored, not the total number of event-lines.

### 4.4 Advance method and determinism (Q17)

- Default advance method is **per-tick polling** of watched, non-frozen event-lines. "No recalculation" of WT/CT is achieved by per-tick advance; a rate change is absorbed as a change to the event-line's increment, never as a `due_tick` rewrite.
- **Prediction depth N is deferred**: the watched-set is re-evaluated per simulated step and is independent of N. The concrete definition/tuning of N is **not a core decision** — it is an input to prediction (EQM-033) and the performance budget (EQM-102). Recorded as deferred (Q17).

### 4.5 Identity and lifecycle (Q26)

- An event-line / counter's **identity equals the meaning-unit the game wants to count** — this is the one invariant. The id is **stable, serializable, and deterministically assigned** (same class as event sequence / actor_id). Issuance order is unique (Q20), so assignment is deterministic across replay.
- **Lifecycle**: per-entity progression cleanup on entity removal follows actor lifecycle (Q10); **actor_id reuse is forbidden** (§13).
- **Stacking is acceptance-defined, not a universal rule**: independent stacks → separate counters; refresh → reuse a single counter; shared pool → one shared counter. The model expresses all three and **hardcodes none** (e.g. buff "uses_left reuse" is not a built-in law).

---

## 5. Conditions: resolution vs invalidation (Q05/Q06/Q18/Q19)

Two **distinct** concepts (do not conflate — this was an explicit correction):

- **Resolution** — the event produces its effect. `solve_conditions` are evaluated as **AND** (all must hold).
- **Invalidation / expiry** — the event drops without producing its effect. `invalidation_conditions` are evaluated as **OR** (any one drops it). Eager cascade (Q05), tick duration expiry, and reaction-count exhaustion (Q06) are all invalidation conditions.

A condition is one of: `(event-line, threshold, comparison)`, a reaction/uses counter, or a trigger predicate. Each event may declare one or more solve and/or invalidation conditions. The condition that fires is recorded in the trace as `closed_by: <condition id>` (§11).

### 5.1 AND-invalidation → decremental counter event-line

A "for-all" invalidation (all of several terms must be exhausted) is expressed by funnelling the terms into a **decremental counter event-line**: each term decrements it, and the invalidation condition is `counter <= 0`. This keeps invalidation OR-shaped at the event level while still expressing AND-exhaustion.

### 5.2 OR-resolution → race pattern

`solve_conditions` are AND-only at the event level. An OR-shaped resolution need ("resolve if *any* of these holds") is expressed as a **race**: issue several events for the **same effect**, each with a different `solve_conditions`, all referencing a (usually shared) event-line; when one resolves, the others are dropped together by an OR `invalidation_conditions`. What is issued is **events**, not multiple event-lines (CONCEPTS §3).

- A **race-group id** ties the racing events together.
- **3-display separation** (concept contract; implementation in Phase 8/9): the same effect appearing as several racing events must be presented distinctly across three audiences, or it looks like the effect happened multiple times:
  1. **EQM-internal debug** — show all race candidates.
  2. **game-developer debug** — summarise the race as one "resolution candidate group".
  3. **in-game presentation** — present only the winner, once.

### 5.3 Eager vs lazy evaluation (Q19)

The lazy/eager distinction is narrowed to *how* an invalidation condition is evaluated:

- **lazy** — evaluated at reference time (when the event is about to resolve); standard, recorded as `invalid_event_skipped`.
- **eager** — evaluated immediately on a state change; expressed as a **trigger-type invalidation condition** riding the existing trigger mechanism (Phase 6). Numerical "eager" conditions that an event-line can express are instead evaluated at the deterministic **sweep point** (§6) — "looks eager, evaluated at a defined point."

---

## 6. Sweep point (Q09 first / Q19)

The **sweep point** is the **collection window after each event resolves**. Triggers do not interleave *during* a resolution; after the resolution completes, the sweep collects and arms/evaluates triggers and re-checks numerical (event-line) invalidation conditions. A single event's resolution is **atomic** with respect to trigger interleaving. This makes determinism checks simple: trigger effects are batched at well-defined points, not scattered mid-resolution.

---

## 7. Composite events and the comparator hook (Q04/Q09/Q11/Q20)

- "Simultaneous" events (WeGo turns, mutual KO, simultaneous threshold arrivals) are represented by a **composite event**: several effects bundled into one atomic resolution. The core keeps a **total order** — it does **not** introduce parallel resolution that breaks the total order. *Which* composite is next is decided by the int comparator (§3), unchanged.
- The order of effects/targets **inside** a composite (and any over-cap behaviour) is delegated to an **acceptance-provided deterministic comparator hook** (a Resource/Callable). Its input may include event-line values and float, and any serializable state.
  - **float is allowed here only** — inside the composite-internal/effect ordering layer — and **never** in the core ordering key (§3, §12). This is a scoped exception, documented as such.
  - **live object references are forbidden** in the comparator input (serializable state only), so it survives snapshot/replay.
  - the comparator is **golden-covered** (its output participates in the canonical trace).
  - **final fallback** when the comparator does not decide: **event issuance order on the default event-line**.
- **Parallel/simultaneous issuance is forbidden** — issuance is always given a unique order, so the fallback is always well-defined and replay is deterministic.
- The core guarantees of a composite: **atomicity, total order, serializability, trace coverage.** Member-resolution order and effect semantics are acceptance-defined *through this one hook* — not by free-form code — which is how freedom and determinism coexist (Q04 answer).

---

## 8. Reentrancy spec (Q02/Q21)

Window nesting and trigger nesting are described as **one reentrancy spec**:

- **window nest** — controlled by a **meta level/cost budget** (Q02). Required cost is a monotonic (acceptance-defined) function of nest level; the budget is **not replenished** within a chain; an absolute max depth is an engineering backstop. There is **no cycle guard at the window layer** — depth is bounded by the budget.
- **trigger nest** — controlled by a **bounded round + cycle guard** (EQM-062). The same-tick trigger-chain guard remains a separate layer from the window budget.
- **crossing cases are in v1 scope** (a trigger that opens a window; a trigger inside a window). Evaluation may use a provisional cost design, but the design must **leave room for flexibility** in how the two budgets relate: sharing them (one combined cost) vs separating them (independent window-budget and trigger-nest-budget) is a narrow item left to EQM-061/062. Recorded as such.

Determinism: any acceptance-defined cost decision that uses an uncertain variable must go through a deterministic RNG and be recorded in the trace.

---

## 9. Windows and deadlines (Q03)

- A window open **freezes the global tick by default** (the player thinks; time does not pass).
- A window may optionally carry a **deadline** (act within a time limit or the window closes and time flows again — ATB active mode). A frozen window is the special case **deadline = ∞**.
- This makes ATB / real-time hybrids expressible and is verified in the coverage matrix (EQM-014.02).

---

## 10. Save boundary (Q01/Q22)

- A save is allowed exactly when the **effect-processing-chunk is empty**.
- The effect-processing-chunk is appended **at resolution time, not at issuance time**. Opening a window implies effects are already resolved at the open point, so the chunk immediately after a window-open is empty.
- Therefore the save boundary **coincides with an allowed sync barrier** (§ relationship to Q25 below).
- The save-able nest level cap = the **base-operator window nest level** (acceptance-managed) (Q01).
- A transitional rate change (mid-advance) save is **allowed but not well-supported** for acceptance (auto-save grade only).
- API reservation: `is_save_allowed()` returns a stable result, and an open window stack is explicitly serialized (detail in EQM-070/071). Snapshot-for-save vs snapshot-for-rollback are distinguished; an open draft saved should rollback to the boundary.

---

## 11. Trace record kinds

The canonical trace (EQM-013) already has an **open record-kind schema** (sorted-key canonical encoding; new kinds need no harness change). v1 reserves these kinds beyond `resolved`:

- `event_line_progressed` — an event-line advanced (a→b / rate change / issuance). (Naming decided: not `event_line_advanced`; past-participle form matches `window_opened`/`window_closed`. Q-Round2.)
- `window_opened` / `window_closed` — window lifecycle.
- invalidation records carry `closed_by: <condition id>` (and `invalid_event_skipped` for lazy skips).

Determinism rules (unchanged from EQM-013): ordering keys are int only; fixed key order; no wall-clock / node-path / object address; byte-identical for identical seed/input.

---

## 12. Numeric domain (Q11)

- `tick`, `priority`, AP, meta-cost are **all int** (`tick` assumes int64). Negative-AP permissibility is policy-declared; over-cap behaviour is **acceptance-defined** (routed through the §7 comparator/extension layer), surfaced as a stable error when undeclared.
- **float never participates in core ordering** (§3). float is permitted **only** in the composite-internal/effect-ordering layer (§7) and is excluded from the master comparator. This separates "ordering determinism" from "effect-expression freedom" by layer.

---

## 13. Actor lifecycle (Q10)

- **`actor_id` reuse is forbidden** (preserves save/load and trace identity).
- Pending reservations of a departing/dead actor are routed through the **invalidation path** (§5), not special-cased.
- Round membership updates are **policy-owned**.

---

## 14. Driver / await contract (EQM-032)

The headless core resolves events; a driver advances it. EQM-032 realizes this contract as the `EQManager` node:

- **Who advances**: the consumer (game loop or `EQManager`) calls `step()` / `advance_frame()`; the core never self-drives (the node does not implicitly drive every frame).
- **Suspend semantics**: when a turn becomes ready the node emits `turn_ready` and **suspends** (`step()` returns null) until the consumer calls `finish_action` — the player-input await boundary. (For deeper L3 cases the same suspend point is an open window / awaiting reservation.)
- **Await boundary for presentation**: action presentation happens between `event_resolved` and the next `step()`, so the simulation order is never distorted by presentation timing (Simulation/presentation split).
- **Frame-budget advance**: `advance_frame(budget)` resolves up to a per-frame budget (auto-finishing turns) to avoid large-battle hitches, **without changing determinism** — the order/trace is identical regardless of how many events a frame resolves. Coexists with `SceneTree` pause and `EditorUndoRedoManager` for editor mutations.

---

## 15. Over-generalization guardrails (Q23)

The model expresses many systems, but v1 deliberately **does not** implement:

- **grouped / micro-event-line** (Q24) — an RTS-scale auxiliary line; used only to confirm the model could absorb that edge case later. Out of v1 implementation.
- **sync barrier as a core named concept** (Q25) — event-line simultaneity is *an example* of a sync barrier but not all of them. The core does not name it; supporting acceptance-side sync-barrier design remains an ongoing concern, not a v1 core primitive.
- **multiple master timelines** (Q13) — one manager = one master timeline + N event-lines; concurrent theaters (4X) map via event-lines, not multiple timelines.

These are recorded so later generalization does not retro-justify scope creep now.

---

## 16. Phase 1/2 reservation vs Phase 4/5 implementation

**Frozen now (contract / schema field names / trace kinds — changing these later is a backward-incompat break to avoid):**

- the master ordering comparator and reschedule-only rule (§3) — *implemented* (EQM-010/011).
- snapshot schema with `schema_version` and stable load error (EQM-012) — *implemented*.
- open trace-kind schema + the kinds in §11 (EQM-013 for the schema; kind names reserved here).
- field-name contracts: `solve_conditions` / `invalidation_conditions` / `close`-by id / race-group id / event-line id / composite comparator hook slot / window deadline property / reservation rumination (Q14: no AP re-charge default + policy hook).

**Deferred to Phase 4/5+ (backend/runtime impl, must honour the frozen contracts):**

- event-line progression backend and per-tick polling (Phase 4/5).
- AP recovery / ready-reservation runtime (Phase 5, EQM-052).
- trigger/reaction engine and the reentrancy budgets' runtime (Phase 6).
- presentation pipeline incl. the 3-display separation (Phase 8).
- prediction depth N tuning (EQM-033) and performance budgets (EQM-102).

If implementing any deferred item reveals that a frozen contract is wrong, the resolution is to **update the plan/queue and re-freeze** (with a recorded rationale), not to silently break compatibility — pre-1.0 migration stance is `defer`/`replace` per `PROJECT_PROFILE.md`.

---

## 17. References

- Concepts: `docs/design/EVENT_MODEL_CONCEPTS.md`
- Decisions registry: `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` (Q01–Q26)
- Rationale: `docs/review/EVENT_MODEL_OPEN_QUESTIONS_SYNTHESIS_2026-06-14.md`
- Ordering/trace proof: `docs/devflow/policy/DETERMINISM_TRACE_TEST_POLICY.md`
- Resilience modes: `docs/devflow/policy/RUNTIME_RESILIENCE_POLICY.md`
- Coverage matrix (sibling task): `docs/design/ORDERING_MODEL_COVERAGE.md` (EQM-014.02)
