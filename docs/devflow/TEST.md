# Devflow Test Index

This file describes how Autopilot verifies work in this repository.

## Verification commands

### Standard regression

```sh
./tools/test.sh
```

This is the standard completion gate. It collects regression tests and the
Python/UI/golden/package checks, but it does **not** collect
`test_project/tests/performance/`.

### Independent performance lane

```sh
./tools/test.sh --performance
```

This explicitly collects only `test_project/tests/performance/`. It does not
run regression tests, Python/UI audits, golden comparison/update, or package
checks. It is not a substitute for the standard regression command.

Both commands use the same exit contract:

- `0` — all runnable checks passed.
- `1` — a check failed.
- `3` — `BLOCKED_BY_TEST_ENV` (a required tool such as Godot is missing).

An unknown suite/mode or a selected suite that discovers zero test files exits
non-zero. A missing expected suite is never an empty green run.

## Lane ownership

| lane | owns | must not own |
|---|---|---|
| regression (`./tools/test.sh`) | correctness, ordering, lifecycle, serialization, API, golden, UI, package | performance file discovery, wall-clock thresholds |
| performance (`./tools/test.sh --performance`) | deterministic work counts, scale fixture execution, environment-labelled elapsed observations | API/trace/schema acceptance, golden updates, UI/Python/package checks |

Deterministic work counts are portable hard gates: examples include total armed,
candidate count, `condition.matches()` call count, and fired count. New raw
wall-clock observations are advisory because they depend on the Godot build and
host. Existing EQM-102/112 coarse budget guards remain performance-lane checks,
but each is paired with an exact workload sentinel and is not a cross-host SLA.
Every reported elapsed value includes the run id and available environment
metadata; elapsed alone must not become the only acceptance proof.

## Environment requirements

| requirement | expected value | how to check |
|---|---|---|
| runtime / framework | Godot 4.x (headless) | `godot --version` (or `$GODOT --version`) |
| test runner | Godot headless GDScript runner with explicit regression/performance suite | invoked by `tools/test.sh` |
| scripting helper | Python 3 (static audits, manifest/link checks) | `python3 --version` |
| build tools | none (GDScript addon) | — |

If a required tool is missing, the selected command exits `3` and Autopilot records `BLOCKED_BY_TEST_ENV` with the exact command and output, instead of marking product implementation complete.

The Godot binary is discovered via the `GODOT` environment variable, else `godot`, else `godot4` on `PATH`.

## Regression paths

| path / command | category | what it proves | when to run |
|---|---|---|---|
| `./tools/test.sh` (Godot regression suite) | Core / Policy / Trigger / Transaction / Presentation | scheduler ordering, policy contracts, reactions, rollback, flush; performance directory excluded | EQM-010 以降 |
| `test_project/tests/trigger/test_eq_reaction_fire_context.gd` (上記 runner が自動収集) | Trigger / Transaction | 独立 FIRE occurrence、cause の immutable projection、schema-v5 migration、schema-v6 exhausted-expiry checkpoint、exact 1-event解決境界 | EQM-132, EQM-133 |
| `test_project/tests/transaction/test_eq_reservation_intervention.gd` | Transaction / Snapshot / Trace | PREPARED singletonへの発行時meta介入、同値成功、回避不変、effect未実行、schema-v7 roundtrip、group/context fail-closed | EQM-135 |
| Godot golden-trace tests under `tests/golden/` | Determinism trace | same-seed replay byte-identical, permutation/prediction purity | EQM-013 以降 |
| Godot UI-headless tests under `tests/ui_headless/` | UI / metric | layout metric P0, state matrix, interaction contract, projection integrity | EQM-090 以降 |
| `python3 tools/ui_static_audit.py` | UI static audit | source 上の no-op button / debug leakage / generic picker pattern | EQM-087 以降 |
| Godot package/clean-load smoke | Package / release | addon enables in a clean project; sample isolation | EQM-002 / EQM-103 |

## Performance paths

| path / command | category | what it proves / records | owner |
|---|---|---|---|
| `./tools/test.sh --performance` | Performance suite boundary | only `test_project/tests/performance/` is collected; non-performance checks are absent; zero-file/unknown mode fail closed | EQM-136 |
| `test_project/tests/performance/` | Scheduler / Trigger / State / Relation / Event-line | EQM-local deterministic work-count gates and environment-labelled elapsed observations | EQM-102, EQM-112, EQM-134, EQM-136 |
| `docs/design/RUNTIME_PERFORMANCE_PROFILE.md` | Measurement record | workload definition, hard-gate counts, advisory elapsed, environment, and residual hot paths | EQM-136+ |

Configured optional helper checks may report an explicit skip when their
feature is not present. The selected Godot suite itself is required: missing
suite files or zero discovered files fail rather than skip.

## Consumer comparison boundary

Performance fixtures must be self-contained in this repository. Consumer
projects may inform which axes and scales matter, but their repositories,
tests, scenes, content, or measured times are not imported or compared. In
particular, Amberground is not an EQM benchmark oracle or baseline.

EQM can claim only what its headless paths measure: scheduler/backend work,
trigger candidate filtering and full-condition calls, event-line/sweep work,
state/relation operations, lifecycle, and serialization. Rendering, AI,
pathfinding, consumer effect handlers, asset loading, and end-to-end frame rate
remain consumer-owned.

## Golden fixture rule

`tests/golden/` の fixture は自動更新しない。`./tools/test.sh --update-golden <case>` の明示 flag + self-review への diff 理由記載が必須 (`docs/devflow/policy/DETERMINISM_TRACE_TEST_POLICY.md`)。Golden operation は regression lane のみで、`--performance` と併用しない。

## Completion proof rules

A task may be marked `COMPLETE` only when:

- Acceptance in `IMPLEMENTATION_QUEUE.md` is satisfied.
- Relevant test paths above passed, or an environment-blocking result (`BLOCKED_BY_TEST_ENV`) was documented.
- A performance task ran both `./tools/test.sh` and `./tools/test.sh --performance`; either command alone is insufficient.
- `docs/devflow/TEST.md` was updated if tests were added or changed.
- Self-review has no `repair-now` items.

## Test result log format

```md
# <TASK_ID> Test Result <YYYY-MM-DD>

## Commands attempted

```sh
<command>
```

## Result

<pass/fail/blocked summary>

## Lane / environment

<regression or performance; run id; Godot build; OS/CPU when elapsed is reported>

## Performance evidence (performance lane only)

<hard work-count gates; advisory elapsed values; no consumer-project comparison>

## Classification

`passed` | `repair-now` | `known-env-failure` | `pre-existing` | `accepted-risk`

## Follow-up

<none or queue task ids>
```
