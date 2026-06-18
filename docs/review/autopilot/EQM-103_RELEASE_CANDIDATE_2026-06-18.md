# EQM-103 — v1.0 Release Candidate proof + self-review (2026-06-18)

Pattern: P0 (orchestrator-direct — release proof). Repair: 0. **Final queue task.**
**STOP honored: no external AssetLib upload performed (§8.4) — that is the user's action.**

## Execution summary

Prepared the v1.0 release candidate: MIT `LICENSE`, `plugin.cfg` bumped to `1.0.0`,
README refreshed (status/install/manual links/license/clean-room), the snapshot schema
compatibility stance declared, the AssetLib submission requirements checked (form NOT
submitted), and clean-room hygiene applied to user-facing genre names. Clean project
load and all gates verified green.

## Changed files

- `LICENSE` (new — MIT), `addons/event_queue_manager/plugin.cfg` (version 1.0.0 + fuller description).
- `README.md` (status → v1.0 RC; install steps; manual/demo links; MIT + clean-room note).
- `addons/event_queue_manager/plugin.gd` (comment corrected: docks are implemented projection-first Controls; editor-mounting is a tracked follow-up).
- `docs/design/SNAPSHOT_COMPAT_V1.md` (new — schema stance).
- `docs/manual/policy_selection.md`, `demos/stack_resolution/stack_resolution.gd` (clean-room: genre brand names → generic mechanic names).

## Acceptance result — met

| acceptance | result |
|---|---|
| clean project load | `./tools/test.sh` PASS (files=48 checks=658 failures=0); Godot import log has 0 errors; all addon scripts parse + register |
| addon manifest | `plugin.cfg` v1.0.0 with name/description/author/version/script; `plugin.gd` valid (`@tool EditorPlugin`, registers EQManager type) |
| docs links | README links the 4 manual chapters + demos + design docs; all paths exist |
| sample isolation | demos are LEARNING-PATH samples (header banners); no demo is a default; `EQTemplateGenerator` two-step sample separation (§5.10 metric enforced) |
| final self-review | this document |
| snapshot schema compatibility stance declared | `SNAPSHOT_COMPAT_V1.md`: **preserve** within v1.x, **migrate** on a break (version bump + migrator), never silent **replace**, **defer** v2 tooling; backed by the `is_supported_version` fail-safe |
| LICENSE chosen (AssetLib-compatible) | **MIT** (`LICENSE`) — permissive, AssetLib-accepted |
| AssetLib submission requirements checked | checklist below — everything required is present; the submission form itself is NOT filed (external action, user's call) |
| copied game names treated clean-room | no third-party game assets/code/trademarks bundled; user-facing genre names genericized; demo names (hero/orc/slime/knight/mage) are original |

## AssetLib submission checklist (ready — NOT submitted)

The Godot AssetLib web form requires the following; all repo-side prerequisites are met.
Filing the form is an **external publish** and is left to the user (§8.4).

| requirement | status |
|---|---|
| public Git repository URL | present (this repo) |
| commit hash / tag to publish | **user action**: tag `v1.0.0` at the chosen commit, then reference it |
| plugin name / version | `Event Queue Manager` / `1.0.0` (plugin.cfg) |
| license | MIT (`LICENSE`) — AssetLib-compatible |
| description | plugin.cfg + README |
| category | recommend **Tools** (editor/runtime ordering utility) |
| Godot version | 4.x (developed on 4.6.2) |
| icon (optional) | **not present** — a 64–128px `icon.png` is recommended before submission (tracked follow-up; optional) |
| README / docs | present (README + `docs/manual/`) |

To publish, the user: (1) tags `v1.0.0`, (2) pushes the tag, (3) submits the AssetLib
form with the repo URL + tag. None of these are done here.

## Design notes (no shrink, honest scope)

- **Clean load is the real gate.** 658 checks green + a zero-error Godot import prove
  the addon loads and every script (core through L2, editor surfaces, demos) parses
  and registers. No screenshot needed — the projection-first metric harness already
  covers the UI.
- **Schema stance is concrete and backed by behavior.** The preserve/migrate/replace/
  defer decision is not aspirational: `EQSnapshot.is_supported_version` already rejects
  an unknown version with a fail-safe `EQError`, and `EQSaveAdapter.load` returns false
  — so "never silently replace" is enforced today, not promised.
- **Clean-room, conservatively.** No game assets/code/marks ship. User-facing brand
  references ("FFX-style", "MTG-style") were genericized to mechanic categories; design
  docs keep nominative references (identifying known systems is fair use, and they are
  rationale, not shipped UX). Demo content is original.
- **Honest about editor-dock mounting.** The dock Controls exist and are tested; live
  `add_control_to_dock` wiring is editor-only glue that can't be headless-verified, so
  it is declared a tracked v1.x follow-up rather than shipped untested. The plugin.gd
  comment now states this accurately instead of "later phases."

## UX path reduction

- No new input class. The release narrows nothing and adds the consumer's entry points
  (LICENSE, install steps, manual map). Residual follow-ups (declared, not silent):
  `icon.png` for AssetLib; interactive editor-dock mounting; v1→v2 snapshot migrator
  if/when a v2 schema lands.

## Deviations

- No git tag or AssetLib submission performed — both are release-publish actions for
  the user. The RC is *ready* to tag + submit; doing so is out of autonomous scope (§8.4).

## Repair-now / follow-up

None blocking. **The implementation queue is complete through EQM-103.** Declared,
non-blocking follow-ups for a v1.x: AssetLib `icon.png`; editor-dock mounting; snapshot
v2 migrator (deferred until a v2 schema exists).

## Queue status

EQM-103 COMPLETE → **v1.0 release candidate ready.** This is the final task; the run
stops here for user review + the external publish step.
