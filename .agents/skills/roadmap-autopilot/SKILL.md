---
name: roadmap-autopilot
summary: Turn concepts, feedback, evaluations, and approved brainstorms into roadmaps, implementation queues, and iterative implementation tasks.
description: Use this skill to create roadmaps, design implementation queues, execute queue tasks, repair failed tasks, or evaluate completed addon development batches.
---

# Roadmap Autopilot Skill

## Read first

1. User request.
2. `docs/devflow/PROJECT_PROFILE.md`.
3. `docs/devflow/README.md`.
4. `docs/devflow/policy/README.md`.
5. Relevant policy:
   - Roadmap creation: `docs/devflow/policy/ROADMAP_POLICY.md`
   - Queue creation: `docs/devflow/policy/IMPLEMENTATION_QUEUE_DESIGN_POLICY.md`
6. Target `docs/plan/<YYYY-MM-DD>_<ROADMAP_ID>/ROADMAP.md` / `docs/plan/<YYYY-MM-DD>_<ROADMAP_ID>/IMPLEMENTATION_QUEUE.md` only when the request needs them.
7. Project test docs and standard test command.

## Modes

Use the smallest mode that satisfies the request.

| mode | input | output |
|---|---|---|
| `roadmap` | feedback / concept / evaluation | `ROADMAP.md`, `IMPLEMENTATION_QUEUE.md` |
| `queue` | existing `ROADMAP.md` | `IMPLEMENTATION_QUEUE.md` |
| `execute` | implementation queue | implemented task + tests + review + queue update + commit |
| `repair` | failed task / `repair-now` | fixed task + updated proof |
| `evaluate` | repo state + roadmap/queue/reviews | evaluation report + next candidates |

## Execute loop

```text
READY task
  -> task packet
  -> implementation
  -> tests
  -> self-review / repair
  -> queue state update
  -> commit or leave ready for next run
```

## Stop only for

- Missing test environment.
- External credentials or public release upload.
- Destructive action outside the repo.
- Direct contradiction with the active roadmap or user instruction.
