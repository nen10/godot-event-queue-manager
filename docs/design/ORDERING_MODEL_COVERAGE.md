# Ordering Model Coverage Matrix (v1)

status: authoritative for v1 (EQM-014.02, 2026-06-15).

Purpose: demonstrate that the v1 semantics (`EVENT_MODEL_SEMANTICS.md`) **can express** a broad range of turn/event-ordering systems. Generality is proven by mapping, not mandated: independent `EQPolicy` implementations remain permitted (roadmap §1.1) — reducibility shows the model is general, it does not require every system to reduce. Any **unmappable** case becomes a queue candidate **before the Phase 2 API freeze**.

Legend for "event-line representation": **(1)** first-class event-line (own identity, polled) / **(2)** entity/effect state + tick-driven sweep (homogeneous, O(1)) — see `EVENT_MODEL_SEMANTICS.md` §4.2.

---

## Summary

| # | system | event-line | resolve / invalidate | tie-break / member order | window | verdict |
|---|---|---|---|---|---|---|
| 1 | CTB (FFX-style) | per-entity CT, (2) | solve `CT >= turn_threshold`; spend on resolve | comparator hook (base speed) → sequence | — | **mapped** |
| 2 | Energy roguelike | per-entity energy, (2) | solve `energy >= cost`; carry-over remainder | comparator hook → sequence | — | **mapped** |
| 3 | Wait Turn (TO / FFT-CT) | per-entity WT/CT, (2) | solve `WT <= 0`; action cost re-rates next WT | comparator hook (base WT, Q09) | — | **mapped** (next-threshold advance: trace-equality proof owned by EQM-053) |
| 4 | FE player/enemy phase | phase line, (1) | solve `phase == my side` ∧ not-acted | player-chosen order = composite/sequence; membership policy-owned | — | **mapped** |
| 5 | 4X concurrent theaters | N theater lines + shared primary tick, (1) | solve per-theater line thresholds | core comparator interleaves on one master timeline | — | **mapped** (Q13 verified; desyncable independent timelines out of scope) |
| 6 | Stack / LIFO (MTG-style) | — (window-driven) | solve when window closes (no further response) | LIFO = window nest order; reentrancy spec (§8) | nest + meta-cost budget | **mapped** |
| 7 | Pokémon-style speed turn | — (per-turn batch) | composite resolution per turn | priority bracket = core `priority`; speed = comparator hook; speed-tie = deterministic RNG (trace-recorded) | — | **mapped** |
| 8 | ATB (active mode) | per-entity gauge, (2) | solve `gauge >= full` | comparator hook → sequence | deadline window (Q03); wait-mode = deadline ∞ | **mapped** |
| 9 | 行動解決ターン制 (core test case) | AP-recovery line per entity, (1)/(2); reaction-count line | solve `AP_recovered >= prep_time`; invalidate via reaction-count decremental line / triggers | comparator hook; sequence fallback | reaction windows; reentrancy spec | **mapped** (most important) |
| — | grouped / micro-event-line (Q24) | — | — | — | — | **deferred** (RTS auxiliary; model can absorb later) |
| — | sync barrier (Q25) | — | — | — | — | **support** (not a core named concept) |

**Result: all 9 systems map; no unmappable case → no new Phase-2-freeze-gating queue candidate.** Two items are *deferred proofs/scope*, not gaps: (a) Wait-Turn's next-threshold advance must produce a trace identical to per-tick polling — owned by the existing EQM-053 reducibility task; (b) 4X with *independent desyncable* resolution orders is out of v1 scope (Q13). Neither is unmappable under the v1 contract.

---

## Per-system detail

### 1. CTB (Charge Time Battle, FFX-style)

Each actor's Charge Time fills by its speed every tick; on reaching the turn threshold the actor acts, then CT is reduced by the action's cost. A faster actor crosses the threshold more often → more turns.

- **event-line**: per-entity CT, representation (2) — one system event on the primary tick advances every entity's CT by its speed (homogeneous: shared rule + per-entity speed param). first-class line count stays O(1).
- **resolve**: `solve_conditions = [CT >= turn_threshold]` → issue a "turn" event; on resolution, spend cost (re-rate CT down). Heavy action → larger cost → later next turn.
- **tie-break**: equal CT at the same tick → composite comparator hook on base speed; final fallback = issuance order (sequence).
- Maps cleanly; matches the EQM-031 acceptance (faster actor extra turns, heavy-action delay, wait shorter delay, haste/slow next-turn).

### 2. Energy (roguelike, DCSS/Brogue-style)

Actors accumulate energy by speed; act when `energy >= action cost`, spending it and carrying the remainder.

- **event-line**: per-entity energy, representation (2). Same shape as CTB.
- **resolve**: `solve = [energy >= cost]`; resolution spends `cost`, **carry-over** = remainder (state on the entity, not a `due_tick` rewrite).
- Matches EQM-040 acceptance (threshold readiness, action cost, speed differences, wait, carry-over).

### 3. Wait Turn (Tactics Ogre WT / FFT CT)

Units have a wait value; the system advances until a unit becomes ready (WT reaches 0 / lowest), it acts, and the action's cost sets the next wait. "Instant resolve to next ready" — no idle stepping.

- **event-line**: per-entity WT/CT, representation (2).
- **resolve**: `solve = [WT <= 0]`; action cost re-rates the next WT (reschedule-only; no `due_tick` rewrite).
- **tie-break**: equal WT → comparator hook on base WT (the explicit Q09 example: lower base WT acts first).
- **advance**: "jump to next ready" is a *next-threshold* advance rather than literal per-tick stepping. The semantics' default is per-tick polling (§4.4); an optimized next-threshold advance is permitted **iff it yields an identical trace**. That trace-equality is the EQM-053 reducibility proof (per-tick polling vs optimized backend identical) — already a queued task, so **not** a new candidate.
- Matches EQM-041 acceptance.

### 4. Fire Emblem player/enemy phase

All units of one side act (player-chosen order), then the other side; phases alternate.

- **event-line**: a phase line, representation (1) — toggles player→enemy→player; or a round counter.
- **resolve**: each unit's turn = event with `solve = [current phase == my side] ∧ [not yet acted this phase]`. Within a phase, the player-chosen order is a composite/sequence; **round membership is policy-owned** (Q10).
- Maps; phase progression is an event-line, turn eligibility is a condition on it.

### 5. 4X concurrent theaters (Q13 verification)

Several theaters of war progress "simultaneously."

- **decision applied**: 1 manager = 1 **master timeline** + **N event-lines** (Q13). Concurrent theaters map to **multiple event-lines sharing the primary tick**, not multiple master timelines.
- **mapping**: each theater = an event-line (or group) advancing on the shared global tick; theater events are gated on their theater's line and resolved on the **single** master timeline, interleaved deterministically by `(tick, priority, sequence)`.
- **verified**: the "concurrent" need is for parallel *progression axes*, which event-lines provide; it is **not** a need for parallel *resolution orders*.
- **out of scope (not a gap)**: a game requiring *independent, causally isolated, desyncable* resolution orders (e.g. separate replay per theater) would need multiple master timelines = explicitly out of v1 scope (Q13). This is a scope boundary, not an unmappable case under the v1 contract.

### 6. Stack / LIFO (Magic-style spell stack)

Effects push onto a stack; players may respond before resolution; the stack resolves last-in-first-out.

- **mapping**: each "add a response" opens/extends a **window**; resolution is LIFO = the window nest order; a stack item resolves when its window closes (no further response).
- **bounding**: nesting depth is bounded by the **reentrancy spec** meta-cost budget (§8), with an absolute-max-depth backstop. Priority passing = window open/close.
- Maps via window nest + reentrancy spec.

### 7. Pokémon-style speed turn

Each turn, all chosen moves resolve in order of priority bracket, then speed; speed ties are random.

- **mapping**: a turn is a **composite/batch**; members ordered by **priority bracket = the core `priority` key** (int, in the master comparator), then by **speed via the composite comparator hook** (Q20, serializable state, float allowed in this layer only), then **speed-tie = deterministic RNG** recorded in the trace.
- Maps; note priority bracket rides the core comparator while speed rides the acceptance hook — exactly the §7/§12 layer split.

### 8. ATB (Active Time Battle, active mode)

Gauges fill in real time; a full gauge lets the unit act; in active mode the clock keeps running while the player chooses (a deadline); in wait mode it freezes.

- **event-line**: per-entity ATB gauge, representation (2); `solve = [gauge >= full]`.
- **window**: the choose-action window carries a **deadline** (§9, Q03). **Wait mode = deadline ∞** (frozen window). real-time hybrid is thus expressible.
- Maps via event-line + deadline window.

### 9. 行動解決ターン制 (Action Resolution Turn-Based — the core demanding test case)

The roadmap's primary stress case. "Reservation preparation (resolution time = 3)" = a prepared action that resolves once the entity's AP has recovered by 3; reactions (counterattack preparation) arm on incoming damage; reaction-count and duration can close a reaction; rumination re-schedules a bounded number of times.

- **event-line**: AP recovery per entity — representation (1) if AP rules are individually distinct, (2) if homogeneous; plus a **reaction-count line** per armed reaction.
- **ready reservation**: `solve = [AP_recovery_line >= prep_time]` → grants the turn after the AP-recovery delay; AP spend/recovery deterministic; the turn closes through **wait** (a commit boundary, Phase 7).
- **reactions**: a counterattack is a **trigger-type** condition armed on an incoming `<損害>` reservation (Phase 6); duration expiry and reaction-count exhaustion are **OR invalidation conditions** (§5), the reaction-count via a **decremental counter line** (`count <= 0`); deadline = ∞ when only the count closes it (Q06).
- **rumination**: bounded re-schedule with a count decrement and a max-chain cycle guard (EQM-062).
- **verified**: every piece maps to an existing v1 contract — this is the system the model was designed around (synthesis §1: event-line + conditions are v1 core *because* of this case). Most important row; mapped.

---

## Deferred / support (recorded, not implemented)

- **grouped / micro-event-line (Q24)** — deferred. An RTS-scale auxiliary line (many entities, many lines). The race pattern (§5.2) is the conceptual entry point; v1 does **not** implement it. Used only to confirm the model could absorb the edge case later.
- **sync barrier (Q25)** — support, not a core named concept. Event-line simultaneity is *an example* of a sync barrier but not all of them. Acceptance-side games will design sync barriers; helping them is an ongoing EQM concern, not a v1 core primitive. (The save boundary, `EVENT_MODEL_SEMANTICS.md` §10, already coincides with an allowed sync barrier.)

## References

- Semantics: `docs/design/EVENT_MODEL_SEMANTICS.md`
- Concepts: `docs/design/EVENT_MODEL_CONCEPTS.md`
- Decisions: `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` (Q13 timeline, Q24/Q25 deferred/support)
- Reducibility proof task: EQM-053 (`IMPLEMENTATION_QUEUE.md`) — per-tick polling vs optimized backend trace-equality
