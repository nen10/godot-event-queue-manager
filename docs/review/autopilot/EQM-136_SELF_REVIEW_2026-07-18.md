# EQM-136 Self Review — production trigger index and independent performance lane

date: 2026-07-18 / pattern: P0 implementation + parallel read-only architecture/test/docs review

## Outcome

PASS. Production `EQTriggerEngine` now evaluates full conditions only for the
resolving target bucket plus wildcard arms. The canonical armed table, public
API, snapshot schema v7, trace schema, fire order, and reaction lifecycle remain
unchanged. Runtime performance tests are no longer collected by the standard
regression command and have an explicit independent command.

## Acceptance check

- [x] **Derived index**: `_armed` remains the sole canonical truth;
  `EQTriggerIndex` and sequence lookup are non-serialized, rebuildable state.
- [x] **Candidate work**: an EQM-owned 1,000-arm production-engine fixture calls
  `matches()` exactly 75 times (25 selected-target + 50 wildcard), rather than
  all 1,000 arms.
- [x] **Order and lifecycle**: target/wildcard interleave, duplicate reservation
  slots, rumination survivors, one-shot closure, actor disarm, and expiry retain
  canonical arm order and existing status transitions.
- [x] **Mutable resources**: changing an already-armed condition's
  `match_target` rebuckets every slot sharing that condition without changing
  its sequence.
- [x] **Expiry work**: the minimum finite end tick makes pre-boundary expiry
  checks O(1); a crossed boundary still scans canonical arm order and preserves
  the strict `current_tick - armed_at > duration` rule.
- [x] **Serialization**: public armed projections contain no sequence/cache keys;
  existing save-load-save and reaction continuation tests pass with the index
  rebuilt from stored arm order.
- [x] **Lane separation**: `./tools/test.sh` excludes `tests/performance/` and
  keeps Python/UI/API/golden checks; `./tools/test.sh --performance` discovers
  only performance files and skips those regression-owned phases.
- [x] **Fail closed**: unknown shell arguments, unknown runner suites,
  performance golden-update attempts, and zero discovered files are rejected.
- [x] **Consumer boundary**: no Amberground test, scene, log, or timing is used
  as a baseline or oracle. Claims are limited to EQM-owned headless runtime work.

## Review findings and repairs

1. A public-looking preload constant would have changed the layer-aware API
   golden. It was renamed `_EQTriggerIndex`; the API surface remains byte-for-byte
   compatible with the existing golden.
2. A `-1`-style expiry sentinel could collide with a negative end tick on direct
   invalid input. The cache now keeps an explicit `has_finite_expiry` boolean,
   preserving the former engine behavior even outside validated submission.
3. A target index can become stale because `EQCondition` is a mutable Resource.
   `match_target` now emits `changed`, and the index tracks exact arm sequences
   per condition so shared conditions rebucket atomically and retain ordering.
4. Existing performance files mixed timing with correctness. Heap ordering,
   trigger-index parity, and state/relation round-trip assertions moved to
   regression-owned files; shared fixtures prevent the two lanes from drifting.

## Performance evidence

- command: `./tools/test.sh --performance`
- run id: `20260718-210344-16925`
- result: PASS — 4 files, 16 checks, 0 failures
- engine: Godot 4.7.stable.official (`5b4e0cb0f`), Darwin arm64, headless
- production trigger fixture: 1,000 total arms, 75 candidates, 75 full-match
  calls, 0 deliberately matching fires, 1,000 arms retained
- measured sweep: 181 microseconds, one iteration/no explicit warmup; advisory
  only and not a cross-host threshold

The complete measurement boundary and residual hot-path ledger are recorded in
`docs/design/RUNTIME_PERFORMANCE_PROFILE.md`.

## Regression verification

- command: `./tools/test.sh`
- final run id: `20260718-210518-25827`
- result: PASS — 74 files, 1,705 checks, 0 failures
- API surface: unchanged; no untagged class or L3 leak
- contract coverage: 34/34 implemented, 0 violations
- UI static audit: P0=0, P1=0
- `bash -n tools/test.sh`: PASS
- `git diff --check`: PASS

The first sandboxed Godot attempt could not write its normal user log path; the
same commands were rerun with user-data write access and passed. Godot's
pre-existing headless UI cleanup warnings remain non-failing and are identical
to the preceding regression run class.

## Follow-up boundary

Event-line full-set sorting, relation-table scans, the default sorted-array
scheduler, trace allocation, and larger-scale ladders remain evidence-gated
future work. They were not bundled into this task, and none is inferred from a
consumer-side benchmark. No repair-now item remains.
