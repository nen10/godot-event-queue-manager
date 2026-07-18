# Runtime Performance Profile

Status: **EQM-138 measured and verified (2026-07-18)**.

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

| path | status after EQM-138 | evidence / next condition |
|---|---|---|
| production trigger target matching | resolved by EQM-136 | 1,000 arms → 75 candidates / 75 full-match calls in the declared fixture |
| target + wildcard candidate assembly | resolved by EQM-138 | exact stable merge; 4.43–4.65x sparse and 9.93–10.24x wildcard-heavy advisory A/B |
| finite-duration expiry inspection | resolved for pre-boundary sweeps by EQM-136 | cached minimum finite end tick makes ordinary pre-boundary checks O(1); crossing a boundary scans canonical arm order once and recomputes the minimum |
| event-line full-set sort before watched selection | deferred | queue only if an EQM-local profile shows it dominates |
| relation expansion / maintenance table scans | deferred | queue only if an EQM-local profile shows it dominates |
| default sorted-array scheduler / live peek | deferred | queue only if an EQM-local profile shows it dominates |
| trace retention / allocation | unmeasured | define an EQM-local fixture before making a claim |

EQM-136/138 completion evidence is recorded in their self-reviews under
`docs/review/autopilot/`. The fixture values are engineering evidence, not
gameplay caps or Amberground support claims.
