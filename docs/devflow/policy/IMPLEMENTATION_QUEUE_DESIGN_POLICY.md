# Implementation Queue Design Policy

## Purpose

Turn an accepted `ROADMAP.md` into an `IMPLEMENTATION_QUEUE.md` that an agent can execute repeatedly.

This policy decides **how to slice roadmap work into tasks**. It does not execute the queue.

## Inputs

- Accepted `ROADMAP.md`.
- `docs/devflow/PROJECT_PROFILE.md`.
- Relevant evaluations, risk notes, and current code/docs/test state.
- Standard verification command.

## Output

```text
docs/plan/<YYYY-MM-DD>_<ROADMAP_ID>/IMPLEMENTATION_QUEUE.md
```

## Queue must include

1. Source roadmap path.
2. Process references.
3. Queue notes.
4. Phase task tables.
5. Dynamic follow-up area.
6. Current pointer.
7. Proof log after execution starts.

## Minimum task columns

| column | meaning |
|---|---|
| `id` | Stable task ID. |
| `status` | Initial state. Usually first task is `READY`; blocked tasks are `BACKLOG`. |
| `dependencies` | Required completed tasks. |
| `plan_dir` | Task packet directory. |
| `deliverable` | What the task produces. |
| `target files` | Expected change areas. |
| `acceptance / test path` | Evidence needed to close. |

Optional when useful:

- `priority`
- `maturity`
- `proof`

## Task sizing rules

Tasks should be product slices, not code fragments.

Good tasks:

- data/resource schema + adapter + validation tests
- asset model + sample asset + package check
- UI screen + state model + workflow test
- performance profile + progress UI + targeted test
- manual update after actual UI exists

Bad tasks:

- create a class only
- add one button only
- write plan and stop for approval
- preserve old UI only because tests expect it
- package/release artifact refresh before feature surface stabilizes

## Dependency rules

- Put model/API cleanup before UI that relies on it.
- Put resource selection/lifecycle before workflow screens.
- Put manual updates after the UI exists.
- Put package/dist refresh after sample assets and docs are stable.
- Put evaluation after large batches.
- Allow destructive test reset when old tests preserve rejected UX/API.

## Acceptance rules

Acceptance must describe observable completion.

- For API tasks: roundtrip, validation, compatibility stance, public methods.
- For UI tasks: user task can be completed; not just widget existence.
- For docs tasks: manual matches current UI/API.
- For package tasks: generated artifact reflects current source tree.
- For performance tasks: measurement and visible progress, not just refactor.

Test paths are required where possible, but tests must not distort the accepted UX/API.

## Initial status rules

- First dependency-free task is usually `READY`.
- Tasks whose dependencies are not complete are `BACKLOG`.
- Research/evaluation tasks can be `READY` if they unblock design.
- Do not mark tasks `COMPLETE` in a newly created queue.

## Queue review checklist

- Does every roadmap phase have task coverage?
- Is the first `READY` task obvious?
- Can dependencies be checked mechanically?
- Is each task useful if implemented alone?
- Is acceptance specific enough for self-review?
- Are process mechanics referenced rather than redefined?
