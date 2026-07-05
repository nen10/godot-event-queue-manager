# Event Model Semantics (v1)

status: authoritative for v1 (EQM-014.01, 2026-06-15). **v1.1 revision (EQM-110, 2026-07-02)**: the implementation-round decisions Q27–Q43 (`EVENT_MODEL_OPEN_QUESTIONS.md` 実装ラウンド; rationale `docs/review/EVENT_MODEL_OPEN_QUESTIONS_SYNTHESIS_2026-07-02.md`) are recorded additively in the sections marked *(v1.1)*. Q01–Q26 decisions are unchanged. **v1.2 revision (EQM-120, 2026-07-05)**: the EBS extension-round decisions Q44–Q54 (拡張ラウンド; rationale `docs/review/EVENT_MODEL_OPEN_QUESTIONS_SYNTHESIS_2026-07-05.md`; request origin `docs/plan/2026-06-09_event_queue_manager/EBS_EXTENSION_REQUEST_2026-07-05.md`) are recorded additively in the sections marked *(v1.2)*. Q01–Q43 decisions are unchanged. Contract-to-implementation tracking: `docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md`.

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

### 4.6 Event-line data model *(v1.1, Q33/Q34)*

An event-line is **data only**: `{id: StringName (deterministic 採番, §4.5), value: int, rate: int per primary tick}`. There is no callable-typed update rule and no rate band — determinism, snapshot, and replay all rest on "rule = data".

- **Two advance paths, no others**: (a) tick-coupled `rate` (polled only while watched and rate ≠ 0, §4.3); (b) explicit `advance(line_id, amount)` issued from a resolving event's effect. A rate change is a **re-rate** issued from an effect; complex update rules live on the *event* side as explicit advances, never inside the line.
- **Threshold conditions are level-semantics** (Q34): a condition `(line, threshold, comparison)` evaluates the *current value* at the evaluation point — there is no crossing-detection primitive. "The moment of arrival" is produced by the resolving event's effect resetting/decrementing the line (CT-style: on act, `CT -= threshold`). Repeating thresholds and multi-crossing-per-poll therefore need no core machinery. Same-tick simultaneous arrivals are ordered by §5.4 key assignment → §7.1 hook → issuance order.

### 4.7 Sweep rule registry — pattern (2) *(v1.1, Q35)*

The pattern-(2) "shared callable + per-entity params" (§4.2) is declared through a **named sweep-rule registry** (same mechanism as §5.5): acceptance calls `register_sweep_rule(name, callable)` at startup; per-entity params live in actor state (serializable data). EQM executes registered rules as a system event on the primary tick and records the progression in the trace (rule name + affected count).

- **Determinism**: rules run in fixed registration order; entity scan order is `actor_id` ascending. Snapshots store only the rule *name* + params; an unregistered name at load is a stable error.
- Declared follow-up (not v1.x-frontloaded): acceptance-intent **effect grouping** for visibility/debug display; recorded in the synthesis, revisited at EQM-119.

### 4.8 Rate modifier-stack (suspension) *(v1.2, Q45)*

An event-line's rate may be modified by a **modifier stack**: the line data (§4.6) is extended additively with `modifiers: Array[{modifier_id: StringName (deterministic 採番, §4.5), kind: ADD | OVERRIDE, value: int}]`, each modifier carrying a lifetime expressed in the existing invalidation vocabulary (expiry event §6.3 / counter line §5.1 — no new lifetime primitive).

- **Effective rate**, recomputed deterministically on every modifier change: if any OVERRIDE modifier is active, the effective rate is the value of the **latest-issued** OVERRIDE; otherwise `base_rate + Σ(ADD values)`. Multiplicative modifiers are **rejected for v1.2** (no current demand; adding them later requires defining integer-fraction values and a fixed rounding rule — additive extension on demand, Q23 guardrail).
- **Suspension** ("前進規則の一時差し替え" — freeze preserving value, slow/haste) = a lifetime-bearing modifier. Freeze = `OVERRIDE 0` (value preserved; a 0-effective-rate line drops out of watched polling per §4.3). Overlap resolves automatically: when one modifier expires, the effective rate is recomputed from the survivors (e.g. freeze during slow → freeze expires → the slow rate is restored without game-side bookkeeping).
- The v1.1 **re-rate** (§4.6) is recast additively as "rewrite of `base_rate`"; modifiers layer on top. Both paths are effects issued from resolving events — the line itself remains pure data.
- Trace: a modifier-caused rate change is an `event_line_progressed` record carrying the `modifier_id` (§11). Snapshot: additive table (§10.1).

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

### 5.4 Evaluation semantics and key assignment *(v1.1, Q27/Q28/Q29)*

- **Level-triggered AND is the only solve semantics** (Q29): all `solve_conditions` terms must hold *at the same evaluation point*. There is no latched ("once satisfied, remembered") mode — latched needs are expressed by writing to an incremental/decremental counter event-line at the moment of satisfaction (same funnel as §5.1). Zone-entry style rules ("N ticks after entering an area") issue/invalidate the pending event on enter/leave.
- **Key assignment** (Q27): when an event's solve conditions are found to hold at a sweep point, it is pushed onto the master timeline with `due_tick =` the global tick of that sweep point, `priority =` the value declared on the event at issuance (default 0), and a **fresh sequence** (same shape as reschedule). Condition-resolved events and delay-scheduled events ride the **same comparator** (§3); no layering rule between them. This holds for conditions referencing non-tick event-lines too — `due_tick` is always the global tick at detection.
- **Invalidation-wins, uniformly** (Q28): if solve and invalidation conditions hold at the same evaluation point, the event is invalidated (no effect). This is a core rule with no per-event opt-out.
- **Issuance is itself an evaluation point** *(v1.1, EQM-118)*: a condition set already holding when the reservation is submitted takes effect immediately (scheduled at the submit tick, or dropped) — a consequence of level semantics; an already-true level never waits for a later sweep to be noticed. Race groups (§5.2): when several racing events' solve conditions hold simultaneously, the winner is decided by the §7.1 hook, falling back to issuance order; losers drop via their OR invalidation. Both outcomes are explained in the trace via `closed_by` (§11).

### 5.5 Named predicate registry *(v1.1, Q30)*

Predicate-type conditions are serialized **by name**: acceptance registers `register_predicate(name: StringName, callable)` on the runtime instance (scene-local, not global) at startup; a pending condition stores only the name. The predicate input is a **serializable view dict only** (same constraint as the §7 hook — no live object references). Loading a snapshot that references an unregistered name is a **stable error** (ERROR_CONTRACT). Direct `Callable` storage (`EQCondition.custom_predicate`) remains transient-only — legal for conditions that never cross a save, **forbidden in the reservation-condition path**.

### 5.6 L2 authoring surface *(v1.1, Q42)*

`EQActionDefinition` is extended additively: `solve_conditions: Array[EQConditionSpec]`, `invalidation_conditions: Array[EQConditionSpec]`, where `EQConditionSpec` is a serializable Resource `{type: LINE_THRESHOLD | COUNTER | NAMED_PREDICATE, line_id, threshold, comparison, counter_start, predicate_name}`. The existing `duration` / `rumination` fields remain as **sugar**, normalized into conditions at validate time (backward compatible). **Acceptance criterion (frozen)**: "counterattack preparation — closes on 3 uses OR 5 turns, deadline ∞ allowed" is declarable in **one `.tres`, zero GDScript lines**, and the trace's `closed_by` shows which condition closed it.

### 5.7 State algebra: inv pairs, coexistence rules, wrapping *(v1.2, Q44/Q46/Q48)*

An abstract algebra over acceptance-declared state types (EBS request R01/R03; EBS skills are acceptance *instances* — none of the concrete pairs below is hardcoded).

- **Involution (inv) pairs**: acceptance declares `inv` pairs of state types (欠損⇄虚飾 etc.) with a per-pair **coexistence rule**, all serializable data:
  - **CANCEL (相殺)** — the pair is represented as **one signed counter event-line** (one axis): positive stacks = state A, negative = state B; granting either state is a signed advance and cancellation is arithmetic. The sign determines which state is active. This *is* the involution made operational: the dual is the same axis walked the other way.
  - **EXCLUDE (排他)** — granting a state first clears its dual, then grants (deterministic order: clear → grant; both trace-recorded). No coexistence instant exists.
  - **COEXIST (共存)** — no runtime interaction; the pair declaration serves authoring-level systematic inversion only (e.g. effect transforms, §6.4).
- **Wrapping (デコレータ / 連鎖)**: a state instance may carry an ordered, serializable list of **wrappers**. A wrapper is a named, **parameter-wise modification** of the wrapped state's grant / clear / effect semantics — the same parameter-wise rewrite shape as §6.4 transforms (e.g. 反転連鎖 = "apply inv to the granted state"; 透徹連鎖 = "on grant, chain-grant through a relation"). Wrapper vocabulary instances are acceptance-defined data; the core freezes only the composition structure, the deterministic order (apply in wrap order; unwrap LIFO), and the trace records (`state_wrapped` / `state_unwrapped`, §11). This is a **state-side composition mechanism, distinct from target expansion** (§6.4) — decided デコレータ型, not relation-propagation.
- **Lifetime composition** *(Q46, 適用確認)*: the two lifetime families and the exception need **no new primitive** — stack-lifetime = decremental counter line (§5.1); turn-lifetime = expiry event (§6.3); 現象 ("not cleared by turns") = simply declaring no turn condition (explicit invalidation only). Owned as golden acceptance instances by EQM-121/128.

---

## 6. Sweep point (Q09 first / Q19)

The **sweep point** is the **collection window after each event resolves**. Triggers do not interleave *during* a resolution; after the resolution completes, the sweep collects and arms/evaluates triggers and re-checks numerical (event-line) invalidation conditions. A single event's resolution is **atomic** with respect to trigger interleaving. This makes determinism checks simple: trigger effects are batched at well-defined points, not scattered mid-resolution.

### 6.1 Resolution pipeline — the one integration contract *(v1.1, Q31; PIVOT)*

One resolution follows exactly this sequence. `EQRuntime.advance` and the reservation pipeline are unified onto it (EQM-113); every mechanism (conditions, event-lines, triggers, chunk, trace) attaches here and nowhere else:

1. **pop** — the scheduler pops the next event; lazy invalidation is evaluated (`invalid_event_skipped` / `closed_by` recorded).
2. **effect** — if the event's definition declares `effect_name`, the runtime calls the registered effect handler (`register_effect(name, callable)`, same registry mechanism as §5.5) with a serializable event view; it returns `Array[EQEffectRecord]`.
3. **chunk** — the returned records are appended to the effect-processing-chunk (this mechanizes §10's "appended at resolution time").
4. **sweep** — triggers are collected/armed/fired (§6.2), numerical (event-line) invalidation conditions are re-checked, and event / event-line issuance and re-rates emitted by the resolution are applied (§5.4 key assignment).
5. **trace → drain** — the trace records the step; the chunk is drained; chunk-empty = the save boundary (§10). Next event.

**Effect callback is optional, with declared linkage** (Q31 reconciliation): `EQActionDefinition.effect_name: StringName` is optional. Empty = explicitly effect-less resolution (legal — WAIT/READY, and the whole L0/L1 `finish_action` style where the developer applies game state at the await boundary; the simple path is never forced through a callback). **Set-but-unregistered is a stable error** — never a silent skip. Manageability comes from the guarantee "declared ⇒ wired": docs/templates/dogfood present the named-effect path as the natural L2 path, because chunk-based save strictness, effect-level trace, and presentation records all flow from it.

Consumer implementation points are exactly: the named effect handlers, (optional) the §7.1 ordering hook, (optional) named predicates (§5.5) and sweep rules (§4.7).

### 6.2 Fired reactions are scheduled, not nested *(v1.1, Q32)*

A reaction that fires during the sweep is **pushed onto the master timeline** (`due_tick = current`, `priority =` its declared value, fresh sequence) and resolves through the normal pipeline (§6.1) on a subsequent pop — it is never resolved in place inside the sweep. This preserves the three-plane invariant (*only timeline events resolve*) and makes reaction order explainable by the §3 comparator; no reaction-specific ordering rule exists (priority + sequence suffice, e.g. "counter before the follow-up" = higher priority at the same tick).

A **cascade** is therefore the repetition "sweep → fire → schedule → resolve → sweep …", bounded by the reentrancy rounds (§8) plus a same-`(event, reaction)` re-fire guard; each round is recorded in the trace with its round number. The v1.0 in-place `fire_cascade` resolution is superseded by this contract (EQM-113).

### 6.3 Expiry is an event *(v1.1, Q40; Q06 是正)*

Arming a duration-limited reservation schedules an **expiry event** at `due_tick = armed_at + duration` (duration = ∞ schedules none). On resolution: if the target is still armed, it is closed with `closed_by: duration` and the optional on-expiry effect runs through §6.1; if it was already closed (e.g. by reaction count), the expiry event drops with a lightweight `closed_by: already_closed` record. Reaction-count exhaustion uses the same vocabulary (`closed_by: reaction_count`). Silent removal of an armed reaction is forbidden.

### 6.4 Resolution-stage rewrites: target expansion and effect pattern transforms *(v1.2, Q48/Q52)*

Step 2 of the pipeline (§6.1) is refined into three deterministic sub-steps. Both rewrite families operate on the **serializable event view** before the effect handler sees it; both are opt-in L2/L3 machinery (absent declarations = the v1.1 behaviour, unchanged).

- **2a — target expansion** *(Q48)*: the runtime expands the event's declared target set through the relation graph (§13.1) according to acceptance-declared expansion rules (relation type ↔ effect tag, data). Traversal is breadth-first in **relation-id ascending** order. Recursion (relation loops) is bounded by **meta-level/cost, in the §8 vocabulary** — each hop draws on the acceptance-declared meta-cost budget; exhaustion stops expansion deterministically (decided: *not* a bare visited-set rule). The expansion result (origin target → expanded list) is recorded in the trace (`targets_expanded`).
- **2b — effect pattern transforms** *(Q52)*: a transform is a named, data-declared, **parameter-wise rewrite of the event view**, typed by the parameter it rewrites: **target rewrite** (対戦術 — redirect to a provenance-chain stage within meta reach, §6.5/§8.2), **state-algebra rewrite** (反転系 — apply §5.7 inv to the effect's state operand), further parameter types additive on demand. Deterministic application order: **meta-level DESC → priority → sequence**. **Multi-pass application is permitted**: which transforms may apply to which (the application structure / skill-effect-graph) is developer-plannable data, and its semantic validation is the **consumer's (EBS's) responsibility** — the core guarantees only the deterministic order, a trace record per application (`effect_transformed`), and a bounded-round engineering backstop (dev fail-fast on runaway, `RUNTIME_RESILIENCE_POLICY.md`).
- **2c — effect handler** (§6.1 step 2 proper) receives the final expanded/transformed view.

### 6.5 Issuance provenance chain *(v1.2, Q52)*

An event carries a serializable **provenance chain** `[{actor, event_id, meta_level}]` from operation root through intermediate operators to the direct issuer. When an operation/window-mediated resolution issues events, the chain is inherited and appended automatically; each stage records the declared meta-level of the operation event that issued it (§8.2). The chain lives **on the event, never on an event-line** — an event-line is progression input, and carrying provenance would break the three-plane separation (§2.1; the request's event-line suggestion was reviewed and declined with user approval). Consumers: target rewrite reach (§6.4 2b), trace explanation.

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

### 7.1 Hook signature and staging *(v1.1, Q38)*

- **No automatic bundling.** The set of events that became resolvable at the same sweep point is passed to the hook as candidates; the hook returns an **order** (permutation): `order_simultaneous(candidates: Array[Dictionary]) -> Array[int]`. Without a hook, the default is sequential resolution in issuance order.
- The candidates view contains only serializable fields within the Q20 scope: entity stats, event tags, event-line values, nest level. The hook's output participates in the golden trace.
- **Staging**: v1.x first delivers the ordering hook only (EQM-115). Composite as an *atomic bundle* is a later explicit acceptance API — deferred, recorded here so it is not re-invented ad hoc. *(v1.2: the deferral is lifted — §7.2.)*

### 7.2 Composite atomic bundle *(v1.2, Q49; supersedes the §7.1 staging deferral)*

The first consumer demand for member-level atomicity arrived (EBS R09 公平 / R03 波及の「同時」): "parallel" effects resolve as one composite at the same tick, **order-independent** (members do not see each other's results), with per-state reactions firing *individually afterwards* through the normal sweep. Sequential same-tick events with the §7.1 hook cannot satisfy this — a sweep runs between members. Therefore:

- A **bundle** is an explicit acceptance API grouping same-tick members into one resolution unit: all member effects are applied (member order = §7.1 hook → issuance order), then **one single sweep** runs after the last member. No trigger interleaving between members.
- The §7 core guarantees (atomicity, total order, serializability, trace coverage) apply as frozen; the bundle is their implementation, not a new ordering authority — *which* bundle is next is still decided by the §3 comparator.
- Trace: bundle id + member sequence (§11). Save boundary: the chunk drains after the bundle completes (§10) — a bundle is atomic with respect to the save boundary.

---

## 8. Reentrancy spec (Q02/Q21)

Window nesting and trigger nesting are described as **one reentrancy spec**:

- **window nest** — controlled by a **meta level/cost budget** (Q02). Required cost is a monotonic (acceptance-defined) function of nest level; the budget is **not replenished** within a chain; an absolute max depth is an engineering backstop. There is **no cycle guard at the window layer** — depth is bounded by the budget.
- **trigger nest** — controlled by a **bounded round + cycle guard** (EQM-062). The same-tick trigger-chain guard remains a separate layer from the window budget.
- **crossing cases are in v1 scope** (a trigger that opens a window; a trigger inside a window). Evaluation may use a provisional cost design, but the design must **leave room for flexibility** in how the two budgets relate: sharing them (one combined cost) vs separating them (independent window-budget and trigger-nest-budget) is a narrow item left to EQM-061/062. Recorded as such.

Determinism: any acceptance-defined cost decision that uses an uncertain variable must go through a deterministic RNG and be recorded in the trace.

### 8.1 Window object model *(v1.1, Q36)*

A window is a first-class runtime object `EQWindow`: `{window_id (deterministic 採番, same class as §4.5 ids), owner_actor, nest_level, kind (acceptance tag — the base-operator level, Q01, is identified by kind), deadline (tick; ∞ = frozen), budget_paid, draft}`.

- **EQTransaction is subordinate**: one window owns one draft; the transaction is the window's draft implementation (the v1.0 standalone API remains as a compatibility wrapper).
- **The L0 await boundary is a window**: `turn_ready` → suspend (§14) is the implicit `nest_level = 0` window. This unifies the save-cap definition (Q01: save allowed up to the base-operator window level) and lets acceptance layer game modes by choosing which kinds count as base-operator.
- open/close are runtime APIs and emit `window_opened` / `window_closed` traces (fields: id / owner / nest_level / deadline / close cause).
- **Budget**: meta-cost is paid from the owner actor's serializable state (acceptance-chosen key); the window stack enforces non-replenishment within a chain (Q02).

### 8.2 Meta-level *(v1.2, Q51 — cross-cutting; EBS request 継続相談点の確定)*

The **meta-level** is a declared int governing intervention strength. It is distinct from the §8 meta-cost *budget* (which bounds depth); the meta-level is a *comparison value*. Frozen rules:

1. **Attachment**: declared on the skill declaration (consumer-side, e.g. the EBS 解決仕様ブロック); the issued event and the opened window **carry** the value at runtime. Undeclared = 0. **Independent of nest_level** — depth and strength are deliberately not conflated.
2. **Domain**: a single int with its total order (a partial order / category comparison was rejected — "incomparable" cases are excluded structurally). **Tie = intervention succeeds**: an intervention passes iff `meta(intervener) >= meta(target)`.
3. **Provenance stages** (§6.5) each carry the declared meta-level of their issuing operation event; the reach of a target rewrite (§6.4 2b) is the furthest chain stage the transformer's level difference allows.
4. The expansion recursion bound (§6.4 2a) draws on the §8 meta-cost vocabulary — no second budget system is introduced.

Consumer-side homework recorded at handover: per-skill meta-level value assignment is EBS game design, outside EQM.

### 8.3 Window premature close (介入の標準効果) *(v1.2, Q50)*

An intervention (e.g. 迎撃 firing on a resolved movement effect) **prematurely closes** the target window by default, subject to §8.2: the close happens iff `meta(intervention event) >= meta(window)`; otherwise the window survives (回避) and the intervention's own effect still resolves normally.

- **Resolved effects stay** — they are resolved timeline events (the intervention's own firing condition depends on them; rolling them back would be self-contradictory). **Pending members are swept** via the invalidation path (each with `closed_by`), then `window_closed(cause: intervention)` is emitted carrying the intervener event id and both meta-levels (explanation-as-data).
- This is a **different semantics from the deadline default** (§9/Q37 draft rollback) — recorded as a distinct close cause, not a variant. The pre-close hook symmetry holds: a game may run an explicit hook before the close; there is no silent default action (UX_PATH_REDUCTION).

### 8.4 Operation-phase recursion, sub-checkpoints, loop resolution *(v1.2, Q53)*

Deep OPERATION nesting (共鳴の 4 段階解決, 鏡面/水鏡の再帰的追加入力) is modeled as **phases = recursive windows**, plus a finer rollback anchor:

- **Phase sub-checkpoints**: a window's draft supports an **ordered list of named phase checkpoints** (deterministic ids) *inside* one window — decided necessary because several phase transitions can occur within a single OPERATION window. Rollback anchors are therefore: window opens (the existing per-window draft, §8.1) *and* intra-window phase checkpoints.
- **Loop detection**: the phase-transition history detects a same-phase revisit; the revisit closes the **minimal cycle**.
- **Resolution (decided: rollback, not forward-transition)**: roll back to the **loop-start checkpoint** (across windows and sub-checkpoints, on the `EQTransaction` working-copy), **clear the inputs of all 鏡面** (loop-participating operation inputs) on the minimal cycle, and resume. The rollback span and the cleared inputs are trace-recorded (`phase_rolled_back`, §11). Re-input UX after clearing is game-side.

---

## 9. Windows and deadlines (Q03)

- A window open **freezes the global tick by default** (the player thinks; time does not pass).
- A window may optionally carry a **deadline** (act within a time limit or the window closes and time flows again — ATB active mode). A frozen window is the special case **deadline = ∞**.
- This makes ATB / real-time hybrids expressible and is verified in the coverage matrix (EQM-014.02).
- **Deadline default behavior** *(v1.1, Q37)*: the deadline is an absolute global tick; the tick keeps flowing while a deadline window is open. On reaching it, the default is **draft rollback + window close** with `window_closed(cause: deadline)`. A game that wants time-out commit (or a forced default action) does so **explicitly** in the pre-close hook — there is no silent default action (UX_PATH_REDUCTION). The post-rollback chunk is empty, so the close is save-boundary-consistent (§10). Concrete time-out UX is acceptance-designed by premise.

---

## 10. Save boundary (Q01/Q22)

- A save is allowed exactly when the **effect-processing-chunk is empty**.
- The effect-processing-chunk is appended **at resolution time, not at issuance time**. Opening a window implies effects are already resolved at the open point, so the chunk immediately after a window-open is empty.
- Therefore the save boundary **coincides with an allowed sync barrier** (§ relationship to Q25 below).
- The save-able nest level cap = the **base-operator window nest level** (acceptance-managed) (Q01).
- A transitional rate change (mid-advance) save is **allowed but not well-supported** for acceptance (auto-save grade only).
- API reservation: `is_save_allowed()` returns a stable result, and an open window stack is explicitly serialized (detail in EQM-070/071). Snapshot-for-save vs snapshot-for-rollback are distinguished; an open draft saved should rollback to the boundary.
- **Enforcement wiring** *(v1.1, Q41)*: `is_save_allowed()` is enforced in the save path (`EQSaveAdapter.save` / `EQManager`) — a chunk-non-empty save is a **stable error**, with no force flag (a transitional save is representable as "chunk empty but window open"). Snapshot **schema_version 2** adds additive tables `event_lines` / `windows` / `armed_triggers`, with pending conditions inline on events; a v1 bundle loads via a v1→v2 migrator (missing tables = empty), and a v2 bundle in a v1 implementation is a stable error (per `SNAPSHOT_COMPAT_V1.md`). Draft serialization default = Q01 (rollback to boundary for save; draft-inclusive snapshots are the rollback side only).

### 10.1 Snapshot schema v3 (reserved) *(v1.2)*

The v1.2 machinery adds state that must survive save/replay. **Schema_version 3** is reserved with the same compatibility pattern as v2 (Q41): additive tables `line_modifiers` (§4.8), `relations` (§13.1), `phase_checkpoints` (§8.4), with state wrappers (§5.7) inline on state entries and provenance chains (§6.5) inline on events. A v2 bundle loads via a v2→v3 migrator (missing tables = empty); a v3 bundle in a v2 implementation is a stable error. Owned by EQM-127 (replay proof: roundtrip across modifiers / relations / provenance / checkpoints → identical pop order + identical trace).

---

## 11. Trace record kinds

The canonical trace (EQM-013) already has an **open record-kind schema** (sorted-key canonical encoding; new kinds need no harness change). v1 reserves these kinds beyond `resolved`:

- `event_line_progressed` — an event-line advanced (a→b / rate change / issuance). (Naming decided: not `event_line_advanced`; past-participle form matches `window_opened`/`window_closed`. Q-Round2.)
- `window_opened` / `window_closed` — window lifecycle (fields per §8.1; close carries a cause, e.g. `deadline`).
- invalidation records carry `closed_by: <condition id>` (and `invalid_event_skipped` for lazy skips).
- **`closed_by` vocabulary** *(v1.1)*: condition ids plus the reserved causes `duration`, `reaction_count`, `already_closed` (§6.3), `actor_removed` (§13). Cascade resolutions carry their **round number** (§6.2). Sweep-rule executions record rule name + affected count (§4.7).
- **`event_invalidated`** *(v1.1, EQM-113)* — the invalidation record kind (carries `closed_by`, and `event_id` when the drop maps to a scheduled event). **`reaction_fired`** *(v1.1, EQM-113)* — a fired reaction was scheduled (fields: `round`, `actor`, `event_id`).
- Effect records carry a deterministic `classification` (important / sensed / offscreen) — **simulation-side data (Q12)**, implemented in EQM-080/081; presentation may not alter it.
- **v1.2 reserved kinds/fields** *(Q44–Q53)*: `relation_bound` / `relation_dissolved` / `relation_rebound` / `relation_inverted` (§13.1); `targets_expanded` (§6.4 2a); `effect_transformed` (§6.4 2b, one record per application); `state_wrapped` / `state_unwrapped` (§5.7); `bundle_resolved` (bundle id + member sequence, §7.2); `phase_rolled_back` (rollback span + cleared inputs, §8.4). `window_closed` cause vocabulary gains `intervention` (with intervener event id + both meta-levels, §8.3); a failed intervention (回避) is recorded as **`intervention_avoided`** (window id + both meta-levels — normal gameplay, not a fault; added with EQM-125). `event_line_progressed` gains an optional `modifier_id` field for modifier-caused rate changes (§4.8). Window/event records carry their `meta_level` (§8.2).

Determinism rules (unchanged from EQM-013): ordering keys are int only; fixed key order; no wall-clock / node-path / object address; byte-identical for identical seed/input.

---

## 12. Numeric domain (Q11)

- `tick`, `priority`, AP, meta-cost are **all int** (`tick` assumes int64). Negative-AP permissibility is policy-declared; over-cap behaviour is **acceptance-defined** (routed through the §7 comparator/extension layer), surfaced as a stable error when undeclared.
- **float never participates in core ordering** (§3). float is permitted **only** in the composite-internal/effect-ordering layer (§7) and is excluded from the master comparator. This separates "ordering determinism" from "effect-expression freedom" by layer.

### 12.1 Progression performance budgets *(v1.1, Q43)*

v1.x targets (measured like EQM-102, Godot 4.6 headless debug): concurrent actors ≤ 200, watched event-lines ≤ 300, armed triggers ≤ 200; the progression machinery (polling + sweep) adds ≤ 0.5 ms to one `advance()` call at those scales; prediction (EQM-033) runs within the same budget at depth N ≤ 20. RTS/STG scales remain out of scope (Q24 deferred). Budget tests are owned by EQM-112.

---

## 13. Actor lifecycle (Q10)

- **`actor_id` reuse is forbidden** (preserves save/load and trace identity).
- Pending reservations of a departing/dead actor are routed through the **invalidation path** (§5), not special-cased.
- Round membership updates are **policy-owned**.
- **Normal departure path** *(v1.1, Q39; Q05 是正)*: `invalidate_actor(actor_id, cause)` is the canonical API — it cancels the actor's pending events, disarms its reactions, cleans up per-entity progression (Q10/Q22), and records `closed_by: actor_removed`. It behaves identically in dev and shipped modes (mode-neutral: death mid-battle is normal gameplay, not an anomaly). `EQNodeBridge.on_actor_freed` calls it. Only an event for an unregistered actor that *bypassed* this path remains a contract violation (dev halts). Events *targeting* a removed actor are not core's concern — acceptance expresses those via invalidation conditions (named predicate / counter); revive/summon-style rules that address removed actors are intentionally left to acceptance design (no core pre-emption; revisit on demand).

### 13.1 Relation graph *(v1.2, Q47)*

Persistent directed actor-to-actor relations (月/主 → 星/従) become first-class serializable data:

- **Relation instance** = `{relation_id: StringName (deterministic 採番, same class as §4.5 ids), type, from_actor, to_actor}` in a serializable table (snapshot v3, §10.1).
- **Relation type declaration** (data): `{name, 分類 tag (追跡/求心/公平 …, acceptance vocabulary), inv 反転形 (e.g. 復讐 = 追跡の反転 — §5.7 の inv と同じ対合形), 構造制約 (TREE | GRAPH — tree violation at bind time is a stable error, dev fail-fast / shipped skip+log), 維持条件 (EQConditionSpec; spatial predicates are game-supplied NAMED_PREDICATE, Q12 の延長), 評価 sweep (declared per type; default = the primary tick's declared threshold, i.e. the game's "T開始時" — §4.7 registry 流用), 解消時規則 (NONE | SERIAL_SUTURE)}`.
- **SERIAL_SUTURE (直列縫合)** is the only rebinding pattern in the v1.2 vocabulary (decided; additive extension on demand): when a relation in a serial chain dissolves, the adjacent relations re-bind to each other. Recorded as `relation_rebound`.
- **Maintenance**: the declared sweep evaluates 維持条件; failure dissolves through the 解消時規則. **`invalidate_actor` integration (decided)**: an actor's departure dissolves all incident relations *through the same 解消時規則 path* (trace: `closed_by: actor_removed` + `relation_dissolved` / `relation_rebound`) — no special-cased silent removal.
- Bind / dissolve / rebind / invert are trace-recorded (§11). Consumers: target expansion (§6.4 2a), 公平 composite acceptance (§7.2), EBS relation skills.

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

### 16.1 Re-freeze record *(v1.1, EQM-110, 2026-07-02)*

The deferred list above **fell through**: queue Phase 4–6 completed (and v1.0 RC shipped, EQM-103) delivering the AP/ready runtime, a trigger engine, and the presentation pipeline, but **not** the event-line backend, condition sets, race pattern, comparator hook, or window machinery — and no deferral was recorded at the time (audit: `docs/review/EVENT_MODEL_DESIGN_GAP_AUDIT_2026-07-02.md`). Per this section's own rule, the plan is now updated and re-frozen:

- **v1.0 implemented scope (honest record)**: master ordering + reschedule-only (§3), snapshot v1 + stable load error, open trace-kind schema, L0/L1 policies, L2 skeleton (reservation kinds / trigger conditions / transaction draft / effect records / presentation), resilience two-mode, actor registry.
- **Still reserved → owned by the v1.1 implementation round** (queue Phase 11, EQM-110..119; tracking: `docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md`): conditions contract (§5.4–§5.6 → EQM-111), event-line backend (§4.6–§4.7 → EQM-112), resolution pipeline + closed_by vocabulary + departure path + expiry events (§6, §13 → EQM-113), window object model + deadline (§8.1, §9 → EQM-114), ordering hook (§7.1 → EQM-115), race pattern (§5.2 → EQM-116), snapshot v2 + save enforcement (§10 → EQM-117), reducibility re-proof (EQM-118), authoring surface (§5.6 acceptance criterion → EQM-119).
- Q27–Q43 details recorded in this revision are **frozen at the same strength** as the v1 contracts; the coverage matrix + `tools/check_contract_coverage.py` gate keeps "declared but unimplemented" from recurring silently.

### 16.2 v1.2 freeze record *(EQM-120, 2026-07-05)*

The EBS extension round (Q44–Q54; request R01–R12; consultation rounds 2–3 all user-decided, rationale in the 2026-07-05 synthesis) freezes the following contracts at the same strength as v1/v1.1. Coverage rows are `reserved` until each owning task flips them:

- rate modifier-stack (§4.8 → EQM-121); state algebra: inv pairs / coexistence rules / wrapping (§5.7 → EQM-121)
- relation graph (§13.1 → EQM-122)
- target expansion + effect pattern transforms (§6.4 → EQM-123); issuance provenance chain (§6.5 → EQM-123)
- composite atomic bundle (§7.2 → EQM-124; lifts the §7.1 staging deferral)
- meta-level (§8.2) + window premature close (§8.3) → EQM-125
- operation-phase recursion / sub-checkpoints / loop rollback (§8.4 → EQM-126)
- snapshot schema v3 (§10.1 → EQM-127); v1.2 trace kinds (§11, delivered with their owning sections)
- EBS acceptance suite: 確認系 Q54 (R04/R06/R08/R09/R11/R12) + authoring additions (§16.2 → EQM-128)

Consumer-side responsibilities recorded at handover (not EQM contracts): spatial predicates via NAMED_PREDICATE (game), defense-stack substance (game), transform application-structure validation (EBS), per-skill meta-level assignment (EBS). All v1.2 machinery is L2/L3 opt-in; the L0/L1 surface is unchanged (EQM-023 gate).

---

## 17. References

- Concepts: `docs/design/EVENT_MODEL_CONCEPTS.md`
- Decisions registry: `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` (Q01–Q26; 実装ラウンド Q27–Q43; 拡張ラウンド Q44–Q54)
- Rationale: `docs/review/EVENT_MODEL_OPEN_QUESTIONS_SYNTHESIS_2026-06-14.md`, `docs/review/EVENT_MODEL_OPEN_QUESTIONS_SYNTHESIS_2026-07-02.md`, `docs/review/EVENT_MODEL_OPEN_QUESTIONS_SYNTHESIS_2026-07-05.md`
- EBS extension request (received copy): `docs/plan/2026-06-09_event_queue_manager/EBS_EXTENSION_REQUEST_2026-07-05.md`
- Contract coverage: `docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md`
- Ordering/trace proof: `docs/devflow/policy/DETERMINISM_TRACE_TEST_POLICY.md`
- Resilience modes: `docs/devflow/policy/RUNTIME_RESILIENCE_POLICY.md`
- Coverage matrix (sibling task): `docs/design/ORDERING_MODEL_COVERAGE.md` (EQM-014.02)
