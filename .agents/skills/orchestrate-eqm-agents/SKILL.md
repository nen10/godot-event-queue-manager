---
name: orchestrate-eqm-agents
summary: Drive an Event Queue Manager queue task through contract → route → gate → merge using parallel, delegated, competitive, or exploratory execution instead of single linear autopilot.
description: Use this skill to run queue tasks non-linearly — parallel independent tasks in worktrees, delegate implementation to an executor agent, dual-run a high-value ambiguous task and arbitrate by gate, or spar on a stubborn UI task. For the simple single-task case use the linear loop instead.
---

# Orchestrate EQM agents

You (Opus) are the orchestrator, not the implementer. Your leverage is in
**setting the contract and owning the verification gate**, not in hand-coding
through an executor. Read `docs/devflow/QUEUE_EXECUTION_PATTERNS.md` once per
session before driving a task; `LINEAR_AUTOPILOT_QUEUE.md` remains the default
for the linear spine.

## Read first

1. `docs/devflow/QUEUE_EXECUTION_PATTERNS.md` — roles, patterns, gates.
2. `docs/devflow/QUEUE_OPERATION_RULES.md` — status, proof, dependency sweep.
3. `docs/devflow/PROJECT_PROFILE.md` — gates and commit policy.
4. Target `IMPLEMENTATION_QUEUE.md` row(s) and the matching `ROADMAP.md` entry.

## Pipeline

1. **Pick + read** the `READY` task(s).
2. **Write the contract** (acceptance, depth `surface|integrated|decision`, exact file scope, required gate). `decision` depth is not delegated.
3. **Route**: bounded → executor (P0/P2); independent fan-out → parallel worktrees (P1); high-value ambiguous core → dual-run (P3, arbitrate by golden trace); stubborn UI / spike → exploratory isolated (P4, arbitrate by UI metric P0).
4. **Run** in a worktree (`Agent` with `isolation:"worktree"`, parallel via `run_in_background:true`; or external CLI after user confirm).
5. **Gate (never skip)**: `./tools/test.sh` green for the task-type gate (golden trace / UI metric P0 / resilience two-mode / layer-aware API surface). `ACCEPT` → merge; `REJECT` → relay findings for repair.
6. **Merge + record** only after `ACCEPT`. Only the orchestrator edits the queue, proof log, and golden fixtures; agents never write shared state.

## Hard rules

- Completion is gate-decided, never self-attested.
- Explorer output is a draft on an isolated branch until gated.
- If you want an executor to "be bolder," fix the contract depth instead.
- Confirm before any billed/external agent run or protected-branch merge.
- One golden fixture is never updated by two parallel branches; serialize tasks that touch it.

## Smoke (no billed run)

```sh
./tools/test.sh            # the gate; runs on the current worktree
git worktree list          # confirm isolation before parallel dispatch
```
