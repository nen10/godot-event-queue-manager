# Devflow Porting Checklist

Use this when copying the devflow pack into a new project.

## Required edits

- [ ] Replace `docs/devflow/PROJECT_PROFILE.md` placeholders.
- [ ] Fill `docs/devflow/TEST.md` with the standard verification command and environment requirements.
- [ ] Check `.agents/skills/roadmap-autopilot/SKILL.md` description for project wording.
- [ ] Check `AGENTS.md` read order.
- [ ] Add project-specific forbidden defaults.
- [ ] Add project-specific stop conditions if needed.
- [ ] Create or import the first accepted concept / brainstorm / evaluation.

## First roadmap run

1. Create `docs/plan/<YYYY-MM-DD>_<ROADMAP_ID>/ROADMAP.md` from the accepted concept.
2. Create `docs/plan/<YYYY-MM-DD>_<ROADMAP_ID>/IMPLEMENTATION_QUEUE.md` from the roadmap.
3. Ensure the first dependency-free task is `READY`.
4. Run the Autopilot execute loop.

## Sanity checks

- Roadmap does not contain queue mechanics.
- Queue does not contain long product essays.
- Task packet contains local UX/POLICY/IMPLEMENTATION_PLAN decisions.
- Self-review and test result are proof logs, not permanent specs.
- `repair-now` cannot be moved to backlog.
