# AGENTS.md

Read the smallest relevant set.

- Principles: `docs/devflow/PROJECT_PROFILE.md`
- Policy index: `docs/devflow/policy/README.md`
- Process index: `docs/devflow/README.md`
- Tests: `docs/devflow/TEST.md`
- Autopilot skill: `.agents/skills/roadmap-autopilot/SKILL.md`

## Which document to use

| Request | Use |
|---|---|
| Decide a roadmap from feedback / brainstorm | `docs/devflow/policy/ROADMAP_POLICY.md` |
| Convert a roadmap to implementation queue | `docs/devflow/policy/IMPLEMENTATION_QUEUE_DESIGN_POLICY.md` |
| Write task-level UX / POLICY / IMPLEMENTATION_PLAN | `docs/devflow/TASK_PACKET.md` |
| Execute an existing queue | `docs/devflow/LINEAR_AUTOPILOT_QUEUE.md` |
| Update queue status | `docs/devflow/QUEUE_OPERATION_RULES.md` |
| Design or test editor UI | `docs/devflow/policy/UI_TESTABILITY_POLICY.md` |
| Prove ordering / trace determinism | `docs/devflow/policy/DETERMINISM_TRACE_TEST_POLICY.md` |
| Remove hack UX paths / narrow inputs | `docs/devflow/policy/UX_PATH_REDUCTION_POLICY.md` |

## Autopilot rule

For roadmap execution, do not stop after planning for approval. Select the next valid `READY` task, implement it, test it, self-review it, repair `repair-now` items, update the queue, and commit completed work.

Use the standard verification command defined in `docs/devflow/PROJECT_PROFILE.md` and `docs/devflow/TEST.md`. If the required environment is missing, record `BLOCKED_BY_TEST_ENV` rather than marking implementation complete.
