# Runtime Performance Profile

Status: **EQM-143 measured and verified (2026-07-19)**.

This document records reproducible, EQM-local runtime performance evidence.
It is deliberately separate from correctness, determinism, lifecycle, and
serialization acceptance, which remain owned by `./tools/test.sh` and the
relevant regression tests.

## Lane contract

| item | contract |
|---|---|
| command | `./tools/test.sh --performance` |
| discovery | `test_project/tests/performance/` only; zero files and unknown mode fail closed |
| hard gates | deterministic work counts, exact scale-fixture invariants, and pre-declared coarse guards paired with workload sentinels |
| advisory evidence | new raw elapsed values labelled with run id and available Godot/host environment |
| excluded gates | regression, API/golden, UI/Python audits, package checks |
| completion | a performance task must also pass the independent `./tools/test.sh` regression command |

Wall-clock values are not portable SLAs and are never the sole acceptance
proof. Existing EQM-102/112 coarse guards remain isolated in this lane and run
with exact workload sentinels; EQM-136's newly reported raw elapsed is advisory.
A faster or slower host does not change the algorithmic work-count contract.

## EQM-142 scheduler live-peek fast path

`EQRuntime.advance()` records a resolved event's `tie_break.decided_by` by
asking `EQScheduler.peek_next()` for the next live entry. Before EQM-142,
`peek_next()` always called `backend.ordered()` and then scanned for the first
live entry. That meant every ordinary event resolution copied the full sorted
array backend, and the binary-heap backend sorted a copied heap (`O(n log n)`)
for every trace peek.

EQM-142 first asks the backend for its minimum with `peek_min()`. If that entry
is live, it is exactly the next live event because `EQOrdering` is total. Only
the rare stale-front case (cancelled or superseded entry at the minimum) falls
back to the previous ordered scan. Peek remains non-mutating; lazy invalidation
and trace semantics are unchanged.

### Workload and hard gates

The independent performance fixture drains a heap-backed scheduler with 512 live
events and no stale front. The test-only legacy helper is a copy of the removed
`peek_next()` shape, using the same live scheduler/backend objects.

| path | legacy source work | current source work | hard parity |
|---|---:|---:|---|
| heap drain trace peeks | 511 `ordered()` calls | 0 `ordered()` calls | exactly 512 popped events |
| backend entries copied/sorted for trace peeks | 130,816 triangular remaining entries | 0 entries | same declared workload completed |

Regression proves empty/single queues, live-min mixed order, cancelled-front
fallback, rescheduled-front fallback, legacy-scan parity, steady-state zero
ordered-copy drain, and existing deterministic trace/golden behavior. The
fallback path intentionally preserves lazy invalidation rather than purging
stale entries during a peek.

### Advisory elapsed record

| run id | backend | workload | legacy µs | current µs | speedup |
|---|---|---:|---:|---:|---:|
| `20260719-041804-36685` | binary heap | drain 512 events | 301,161 | 6,051 | 49.77x |

The portable claim is the removal of per-resolution `ordered()` copies in the
ordinary live-min case, not this host's elapsed ratio. Larger heap-backed drains
benefit disproportionately because the removed legacy operation sorted a copy
for every trace peek.

## EQM-143 scheduler reschedule live-entry lookup

`EQScheduler.reschedule()` preserves the old event's kind/actor/payload by first
finding the current live entry for an event id. Before EQM-143, that lookup used
`backend.ordered()` and scanned the copied ordered backend. On a binary heap,
`ordered()` sorts a copied heap, so frequent CTB/energy/wait-turn reschedules
could pay a hidden full-queue sort before inserting the new entry.

EQM-143 adds a private `event_id -> live EQEntry` accelerator mirrored with the
existing generation map. `_generation` remains the liveness source of truth;
`_live_entries` is rebuilt from validated snapshot entries and updated by
push/pop/cancel/reschedule/restore. Lazy stale backend artifacts are unchanged.

### Workload and hard gates

The independent performance fixture reschedules 256 heap-backed live events.
The test-only legacy shape calls a copy of the removed `_find_live()` before the
same current reschedule mutation, isolating lookup work while preserving
identical state transitions. Because lazy reschedule leaves stale artifacts in
the backend, the legacy lookup copies a growing backend: `N^2 + N(N-1)/2`
entries for N reschedules.

| path | legacy source work | current source work | hard parity |
|---|---:|---:|---|
| reschedule live-entry lookup | 256 `ordered()` calls | 0 `ordered()` calls | exactly 256 successful reschedules |
| copied/sorted backend entries | 98,176 entries | 0 entries | live size remains exactly 256 |

Regression proves no backend scan for ordinary reschedule, cancel rejection,
popped-event rejection, restore-rebuilt accelerator, invalid-tick non-mutation,
metadata preservation, and existing scheduler/snapshot/trace behavior.

### Advisory elapsed record

| run id | backend | workload | legacy-shape µs | current µs | speedup |
|---|---|---:|---:|---:|---:|
| `20260719-042251-41408` | binary heap | reschedule 256 events | 185,047 | 779 | 237.54x |

The portable claim is the O(1) live-entry lookup and zero backend copies/sorts
for reschedule target lookup. Backend insertion cost remains backend-owned
(`O(log n)` heap, `O(n)` sorted array).

## EQM-140 watched-only polling and effective-rate cache

`EQEventLines.poll_tick()` previously sorted every canonical line id and then
tested watched membership. Each selected line also recomputed its effective rate
by scanning the complete modifier Array. EQM-140 instead filters the watched keys
to live canonical ids, content-sorts that sparse set, and reads a private derived
effective-rate cache. Canonical value/base-rate/modifier data and serialized form
are unchanged.

### Workloads and hard gates

| path | fixture | legacy source work | current source work | hard parity |
|---|---|---:|---:|---|
| poll selection | 4,096 issued lines + primary; 36 watched keys, 32 live | 4,097 line ids | 36 watched keys | exact 32 live ids in String content order |
| effective-rate lookup | base 7 + 32 additive modifiers | 32 modifier visits | 0 modifier visits + 1 cache read | exact derived value and canonical modifier depth |

Selection therefore removes **113.8x** key inspections at the declared sparse
scale. The effective-rate read path performs no modifier traversal; cache
construction/refresh remains mutation-owned. Regression proves:

- watched and line insertion order do not affect poll trace order;
- watched values are ignored, unknown keys are silent, and input is not mutated;
- base re-rate, additive modifiers, latest override, zero/negative rate, and all
  removal orders refresh the cache exactly;
- invalid operations change neither cache nor modifier sequence;
- in-place restore removes old cache keys, rebuilds from final canonical payload,
  preserves trace/sweep rules, and does not serialize the cache;
- existing snapshot-v3 continuation, event-line trace, and step pipeline remain green.

The read optimization moves one cost boundary: re-rate of a deeply modified line
refreshes its derived value in O(modifier depth), while subsequent reads/polls are
O(1). Modifier add/remove already traverse their canonical Array. Mutation costs
are not included in the lookup-only elapsed claim.

### Advisory A/B method

- Godot 4.7 stable (`5b4e0cb0f`), Darwin arm64, local headless process.
- Test-only legacy helpers are counter-free copies of the removed selector and
  effective-rate function, using the same live objects as production.
- Each value is the average of the central pair from 6 sorted samples after 5
  warmups. Order alternates legacy→current / current→legacy three times each.
- Each selection sample performs 80 assemblies; each rate sample performs 5,000
  lookups. Three complete runs bound ordinary noise.
- These are selection-only and lookup-only ratios, not full poll, `step_tick`,
  frame, consumer, rendering, or effect-handler speedups.

| run id | path | legacy µs / batch | current µs / batch | speedup |
|---|---|---:|---:|---:|
| `20260718-232551-25295` | poll selection ×80 | 371,322 | 1,999 | 185.75x |
| `20260718-232551-25295` | effective-rate ×5,000 | 31,475 | 1,698 | 18.54x |
| `20260718-232613-25681` | poll selection ×80 | 385,718 | 2,083 | 185.17x |
| `20260718-232613-25681` | effective-rate ×5,000 | 31,429 | 1,694 | 18.55x |
| `20260718-232638-27568` | poll selection ×80 | 384,756 | 2,023 | 190.19x |
| `20260718-232638-27568` | effective-rate ×5,000 | 32,111 | 1,757 | 18.28x |

Observed operation-local ranges are **185.17–190.19x** for sparse watched-id
selection and **18.28–18.55x** for depth-32 effective-rate lookup. The portable
evidence is exact semantic parity plus bounded selection/modifier work; elapsed
ratios remain advisory.

## EQM-139 actor-adjacency relation paths

`EQRelationGraph` already maintained a sorted actor-to-relation-id adjacency as
derived state, but actor-local query, expansion, TREE validation, serial suture,
and invalidation still enumerated the canonical full relation table. EQM-139
routes those paths through a fresh copy of the actor's incident ids while keeping
`_relations` canonical. Global maintenance, serialization, and public
`relation_ids()` intentionally remain full-table operations.

### Workload and hard gates

The EQM-owned fixture restores 2,048 GRAPH relations. The selected `focus` actor
has 9 incident relations: 8 of the requested expansion type and 1 other-type
edge. All other relations are unrelated. The test-only legacy helpers are exact
copies of the removed production code shapes and use the same canonical graph.

| path | legacy inspected ids | adjacency inspected ids | deterministic reduction | exact parity gate |
|---|---:|---:|---:|---|
| `relations_of(focus)` | 2,048 | 9 | 227.6x | payloads, deep-copy boundary, relation-id order |
| `expand(focus, link, 1, 2)` | 34,816 | 89 | 391.2x | 17 frontier frames, 9 output actors, BFS order |
| actor invalidation selection | 2,048 | 9 | 227.6x | dissolved count, post-state, complete trace order |

A test-only subclass counts calls made by the production paths. Each path records
zero global `relation_ids()` calls. Invalidation snapshots the original sorted
incident list before mutation, so serial-suture additions are not accidentally
included. Regression also covers lexicographic double-digit ids, self-loop
de-duplication, query ownership, restore rebuild, serial rebound, TREE behavior,
and a repaired duplicate-id restore case whose old endpoints previously left
stale adjacency.

### Advisory A/B method

- Godot 4.7 stable (`5b4e0cb0f`), Darwin arm64, local headless process.
- Each value is the average of the central pair from 6 sorted samples after 5
  warmups. Sample order alternates legacy→adjacency / adjacency→legacy three
  times in each direction.
- Each sample runs 80 `relations_of` calls, 6 bounded expansions, or 150
  invalidation-selection assemblies. Restore/build is outside the timed region.
- Three complete runs bound ordinary run-to-run noise.
- Ratios are operation-local. They are not full `step_tick`, frame, consumer,
  rendering, or effect-handler speedups.

| run id | path | legacy µs / batch | adjacency µs / batch | speedup |
|---|---|---:|---:|---:|
| `20260718-231246-77781` | `relations_of` ×80 | 325,672 | 616 | 528.69x |
| `20260718-231246-77781` | `expand` ×6 | 249,893 | 386 | 647.39x |
| `20260718-231246-77781` | invalidation selection ×150 | 85,810 | 88 | 975.11x |
| `20260718-231308-78743` | `relations_of` ×80 | 318,742 | 614 | 519.12x |
| `20260718-231308-78743` | `expand` ×6 | 250,790 | 387 | 648.04x |
| `20260718-231308-78743` | invalidation selection ×150 | 90,658 | 88 | 1,030.20x |
| `20260718-231337-79346` | `relations_of` ×80 | 321,369 | 621 | 517.50x |
| `20260718-231337-79346` | `expand` ×6 | 251,372 | 383 | 656.32x |
| `20260718-231337-79346` | invalidation selection ×150 | 85,712 | 80 | 1,071.40x |

Observed operation-local ranges are **517.50–528.69x** for `relations_of`,
**647.39–656.32x** for bounded `expand`, and **975.11–1,071.40x** for the
non-mutating incident-selection portion of actor invalidation. These unusually
large ratios reflect eliminating global String sorting, scanning, and—in the old
expansion—deep payload duplication from a deliberately sparse graph. The
portable evidence is the inspected-id reduction and exact semantic parity, not
the elapsed ratio. The timed legacy expansion helper is a counter-free copy of
the removed production function; deterministic inspection counters live in a
separate, untimed oracle.

## EQM-138 stable candidate merge

EQM-136 narrowed full matcher work to target + wildcard candidates, but candidate
assembly still concatenated those buckets and sorted the whole result on every
sweep. EQM-138 keeps each derived bucket in immutable arm-sequence order and
performs a two-way linear merge. Normal arm remains an O(1) append; only the
rare condition retarget into a populated bucket uses ordered insertion.

### Workloads and hard gates

Both scenarios use the production `EQTriggerEngine` with 1,000 armed,
non-matching reactions over 40 target names. The same file also builds an
`EQTriggerIndex` and compares its exact candidate sequence against a
performance-test-only, code-shape-equivalent copy of the removed production
lookup + concat + `sort_custom` assembler using the same full entry objects.

| scenario | wildcard declaration | target + wildcard candidates | candidate share | observed hard result |
|---|---:|---:|---:|---|
| sparse | every 20th arm | 25 + 50 = 75 | 7.5% | 75 matcher calls, 0 fired, 1,000 retained, exact legacy sequence |
| wildcard-heavy | every 4th arm | 25 + 250 = 275 | 27.5% | 275 matcher calls, 0 fired, 1,000 retained, exact legacy sequence |

Regression additionally moves older/shared condition slots into populated
target and wildcard buckets, fixes exact global arm order, and verifies that a
single-bucket result is a fresh Array. Production candidate assembly contains no
full-result sort. API/schema/trace are unchanged.

### Advisory A/B method

- Godot 4.7 stable (`5b4e0cb0f`), Darwin arm64, local headless process.
- Each reported value is the average of the central pair from 6 sorted samples
  after 20 warmups; each sample assembles candidates 500 times in the same process.
- Sample order alternates legacy→merge / merge→legacy, with three batches in
  each order, to avoid a fixed warmup/frequency advantage.
- Three complete performance runs bound ordinary run-to-run noise.
- Ratios measure candidate-array assembly only, not an entire game frame or
  effect handler. Candidate count/matcher count/order are the hard gates; the
  elapsed ratio is advisory.

| run id | scenario | legacy sort µs / 500 | stable merge µs / 500 | speedup |
|---|---|---:|---:|---:|
| `20260718-224906-80604` | sparse | 48,690 | 10,471 | 4.65x |
| `20260718-224906-80604` | wildcard-heavy | 334,863 | 33,713 | 9.93x |
| `20260718-224950-81434` | sparse | 44,995 | 9,752 | 4.61x |
| `20260718-224950-81434` | wildcard-heavy | 335,358 | 33,750 | 9.94x |
| `20260718-225017-81801` | sparse | 48,269 | 10,894 | 4.43x |
| `20260718-225017-81801` | wildcard-heavy | 380,842 | 37,190 | 10.24x |

Observed range: **4.43–4.65x** for 75 candidates and **9.93–10.24x** for 275
candidates. Expressed as time reduction for this assembly-only fixture, that is
**77.4–78.5%** and **89.9–90.2%**, respectively. The larger gain is consistent
with removing O(c log c) sorting as wildcards grow; it is not an end-to-end
runtime claim.

## Comparison boundary

Consumer information may select useful axes and synthetic scales, but no
consumer repository is a benchmark dependency. Amberground tests, scenes,
content, runtime logs, and measured times are not imported, executed, or used
as a baseline/oracle. Results in this document compare only EQM-owned fixtures
and EQM runtime paths.

EQM can verify:

- scheduler/backend operations;
- trigger candidate selection, full-condition call count, fired count, and
  reaction lifecycle;
- event-line and registered-sweep work;
- state/relation operations and serialization;
- headless save/load continuation.

EQM cannot infer consumer rendering FPS, AI/pathfinding time, effect-handler
cost, asset I/O, networking, presentation pacing, or end-to-end game latency.

## EQM-136 production trigger workload

The fixture must exercise the actual `EQTriggerEngine`, not only the standalone
`EQTriggerIndex`. Fill the result columns from the completed performance run;
do not copy values from a consumer project.

### Workload definition

| parameter | declared fixture value | result / note |
|---|---:|---|
| total armed reactions | 1,000 | 1,000 before and after the non-matching sweep |
| target naming domain | 40 | 38 non-empty target buckets; remainders 0 and 20 are wildcard slots |
| wildcard declarations | every 20th arm | 50 |
| selected event target | `target-7` | 25 target slots + 50 wildcard slots |
| matching fired reactions | none (`never-present` tag requirement) | 0; all candidates stay armed |
| finite-duration / expiry cases | excluded from this single-sweep measurement | exact deadline / deadline+1 behavior is regression-owned |

### Deterministic hard gates

| gate | required relation | observed |
|---|---|---|
| canonical armed count | engine count equals fixture declaration | PASS: 1,000 |
| candidate count | equals selected target bucket + wildcard bucket and is less than total armed | PASS: 75 = 25 + 50; 7.5% of armed slots |
| full-match calls | equals candidate count, not total armed | PASS: 75, eliminating 925 full-condition calls for this fixture |
| fired result | equals the regression oracle's semantic result and arm order | PASS: 0 for the deliberately non-matching tag; parity test passes in regression |
| lifecycle | rumination, expiry, disarm, retarget, and restore leave no duplicate/stale slot | PASS: dedicated lifecycle regression + existing reaction/save continuation suite |
| serialization | save-load-save value and continued trace remain regression-owned and exact | PASS: schema/API goldens unchanged; full regression 74 files / 1,705 checks |

### Advisory elapsed record

| field | value |
|---|---|
| run id | `20260718-210344-16925` |
| date/timezone | 2026-07-18 / Asia/Tokyo (JST) |
| Godot version/build | 4.7.stable.official (`5b4e0cb0f`) |
| OS / architecture | Darwin / arm64 |
| CPU / runner context | local headless Godot process; exact CPU model unavailable to the harness |
| iterations / warmup | one measured production-engine sweep; no explicit warmup |
| elapsed statistic and unit | 181 microseconds for the measured sweep |
| notes | advisory only; not a cross-host pass/fail threshold |

## Other performance fixtures

Existing scheduler, event-line, and state/relation fixtures run in the same
explicit performance lane. Their exact file-owned parameters remain the source
of truth, including historically declared coarse guards; every timed fixture
also asserts that its deterministic workload completed. Future self-reviews may
add result rows here when a task changes those paths.

## Residual hot-path ledger

| path | status after EQM-143 | evidence / next condition |
|---|---|---|
| production trigger target matching | resolved by EQM-136 | 1,000 arms → 75 candidates / 75 full-match calls in the declared fixture |
| target + wildcard candidate assembly | resolved by EQM-138 | exact stable merge; 4.43–4.65x sparse and 9.93–10.24x wildcard-heavy advisory A/B |
| finite-duration expiry inspection | resolved for pre-boundary sweeps by EQM-136 | cached minimum finite end tick makes ordinary pre-boundary checks O(1); crossing a boundary scans canonical arm order once and recomputes the minimum |
| event-line full-set sort before watched selection | resolved by EQM-140 | 4,097 canonical ids → 36 watched keys / 32 live; exact content order |
| effective-rate lookup modifier scan | resolved by EQM-140 | depth 32 read → derived cache lookup; mutation refresh remains O(depth) |
| event-line `ctx_lines()` full copy | unmeasured | separate from poll selection; profile before queueing |
| relation-maintenance-only watched lines | correctness audit candidate | current watched input set intentionally unchanged; needs separate semantic proof |
| actor-local relation query/expansion/invalidation | resolved by EQM-139 | 2,048 total / 9 incident; exact parity; 227.6–391.2x fewer inspected ids |
| relation maintenance global scan | retained by design | every relation is an evaluation target; profile separately before changing |
| default sorted-array scheduler / live peek | resolved for ordinary live-min peeks by EQM-142 | heap drain trace peeks: 511 `ordered()` calls / 130,816 copied+sorted entries → 0; stale-front fallback retained |
| scheduler `reschedule()` live-entry lookup | resolved by EQM-143 | heap reschedule lookup: 256 `ordered()` calls / 98,176 copied+sorted entries → 0 |
| scheduler membership scans (`peek(size())` existence checks) | queued as EQM-144 | add `has_event()` and remove full-copy membership scans |
| consumer backend selection | queued as EQM-145 | expose heap only after EQM-142 prevents trace-peek O(n² log n) regression |
| trace retention / allocation | unmeasured | define an EQM-local fixture before making a claim |

EQM-136/138/139/140/142/143 completion evidence is recorded in their self-reviews under
`docs/review/autopilot/`. The fixture values are engineering evidence, not
gameplay caps or Amberground support claims.
