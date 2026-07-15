# Devflow Test Index

This file describes how Autopilot verifies work in this repository.

## Standard verification command

```sh
./tools/test.sh
```

Autopilot must run this command, or record why it cannot run. The script exits:

- `0` — all runnable checks passed.
- `1` — a check failed.
- `3` — `BLOCKED_BY_TEST_ENV` (a required tool such as Godot is missing).

## Environment requirements

| requirement | expected value | how to check |
|---|---|---|
| runtime / framework | Godot 4.x (headless) | `godot --version` (or `$GODOT --version`) |
| test runner | Godot headless GDScript runner | `godot --headless --path test_project --script res://tests/run_all.gd` |
| scripting helper | Python 3 (static audits, manifest/link checks) | `python3 --version` |
| build tools | none (GDScript addon) | — |

If a required tool is missing, `./tools/test.sh` exits `3` and Autopilot records `BLOCKED_BY_TEST_ENV` with the exact command and output, instead of marking product implementation complete.

The Godot binary is discovered via the `GODOT` environment variable, else `godot`, else `godot4` on `PATH`.

## Test paths

| path / command | category | what it proves | when to run |
|---|---|---|---|
| `godot --headless --path test_project --script res://tests/run_all.gd` | Core / Policy / Trigger / Transaction / Presentation | scheduler ordering, policy contracts, reactions, rollback, flush | EQM-010 以降 |
| `test_project/tests/trigger/test_eq_reaction_fire_context.gd` (上記 runner が自動収集) | Trigger / Transaction | 独立 FIRE occurrence、cause の immutable projection、schema-v5 migration、schema-v6 exhausted-expiry checkpoint、exact 1-event解決境界 | EQM-132, EQM-133 |
| Godot golden-trace tests under `tests/golden/` | Determinism trace | same-seed replay byte-identical, permutation/prediction purity | EQM-013 以降 |
| Godot UI-headless tests under `tests/ui_headless/` | UI / metric | layout metric P0, state matrix, interaction contract, projection integrity | EQM-090 以降 |
| `python3 tools/ui_static_audit.py` | UI static audit | source 上の no-op button / debug leakage / generic picker pattern | EQM-087 以降 |
| Godot package/clean-load smoke | Package / release | addon enables in a clean project; sample isolation | EQM-002 / EQM-103 |

未作成の test target / tool は `./tools/test.sh` が存在チェックして skip する (欠落は失敗にしない)。Godot 自体の欠如のみ `BLOCKED_BY_TEST_ENV`。

## Golden fixture rule

`tests/golden/` の fixture は自動更新しない。`./tools/test.sh --update-golden <case>` の明示 flag + self-review への diff 理由記載が必須 (`docs/devflow/policy/DETERMINISM_TRACE_TEST_POLICY.md`)。

## Completion proof rules

A task may be marked `COMPLETE` only when:

- Acceptance in `IMPLEMENTATION_QUEUE.md` is satisfied.
- Relevant test paths above passed, or an environment-blocking result (`BLOCKED_BY_TEST_ENV`) was documented.
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

## Classification

`passed` | `repair-now` | `known-env-failure` | `pre-existing` | `accepted-risk`

## Follow-up

<none or queue task ids>
```
