# Runtime Performance Profile

Status: **EQM-136 measured and verified (2026-07-18)**.

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

| path | status after EQM-136 | evidence / next condition |
|---|---|---|
| production trigger target matching | resolved by EQM-136 | 1,000 arms → 75 candidates / 75 full-match calls in the declared fixture |
| finite-duration expiry inspection | resolved for pre-boundary sweeps by EQM-136 | cached minimum finite end tick makes ordinary pre-boundary checks O(1); crossing a boundary scans canonical arm order once and recomputes the minimum |
| event-line full-set sort before watched selection | deferred | queue only if an EQM-local profile shows it dominates |
| relation expansion / maintenance table scans | deferred | queue only if an EQM-local profile shows it dominates |
| default sorted-array scheduler / live peek | deferred | queue only if an EQM-local profile shows it dominates |
| trace retention / allocation | unmeasured | define an EQM-local fixture before making a claim |

EQM-136 completion evidence is recorded in
`docs/review/autopilot/EQM-136_SELF_REVIEW_2026-07-18.md`. The fixture values are
engineering evidence, not gameplay caps or Amberground support claims.
