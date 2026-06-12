# Roadmap Policy

## Purpose

Turn concept proposals, user requests, feedback, approved brainstorm items, and evaluations into a small, executable `ROADMAP.md`.

This policy decides **what direction to take**. It does not define queue execution steps.

## Inputs

Use only inputs relevant to the request.

- User concept / request.
- Approved brainstorm or product ideas.
- Feedback from implementation or first use.
- Evaluation reports.
- Current code, tests, docs, and package state.
- `docs/devflow/PROJECT_PROFILE.md` product principles.

## Output

```text
docs/plan/<YYYY-MM-DD>_<ROADMAP_ID>/ROADMAP.md
```

## Minimal roadmap content

A roadmap must answer:

1. Why this roadmap exists.
2. What user or developer workflow it improves.
3. What principles are adopted.
4. What principles are rejected or deferred.
5. What phases are needed and why in that order.
6. What each phase produces.
7. What counts as success.
8. What should be queue-designed first.

## Roadmap rules

- Start from the user workflow or product concept, not from file structure.
- Use approved brainstorm items as accepted direction unless the user says otherwise.
- Preserve project-specific values from `docs/devflow/PROJECT_PROFILE.md`.
- Separate “works internally” from “ready for users”.
- Prefer phases that unlock later work.
- Include destructive cleanup when old compatibility, old UI, or old tests block the accepted direction.
- Do not add unaccepted ideas to the active roadmap. Put them in deferred / research / backlog.
- Do not write queue status mechanics, proof logs, or commit steps into the roadmap.

## Phase design rules

Good phases are based on dependency and user value:

- canonical data/API before UI that depends on it
- asset/resource model before editor selection UI
- screen/workflow redesign before manuals that explain it
- implementation before package/release artifact refresh
- evaluation after a completed batch

Bad phases:

- reducing line count for its own sake
- one class per phase
- preserving old UX only because tests expect it
- mixing research, roadmap, queue, and execution log in one file

## Review checklist

- Does the roadmap answer the latest request or feedback?
- Are adopted / rejected / deferred principles explicit?
- Is the order justified by dependencies or product value?
- Is the first queue scope clear?
- Is the roadmap free of process mechanics?
