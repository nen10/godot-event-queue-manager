# EQM-091 Self-Review 2026-06-18

Pattern: P0 (orchestrator-direct — explanation data model + editor surface = design). Repair: 0.

## Execution summary

Built explanation-as-data: `EQOrderExplanation` (core) produces the structured
ordering-key breakdown (due_tick/priority/sequence with value+direction) plus
`decided_by` — the single key that ordered an entry after its predecessor. The
deciding-key logic lives in `EQOrdering.decided_by` (next to `less_than`), so the
explanation can never disagree with the actual sort. `EQDebugInspector` (ui,
order_inspector surface) renders that data as icon+label+integer-value rows and
marks the deciding factor — the runtime never emits a sentence.

## Changed files

- `addons/event_queue_manager/runtime/eq_ordering.gd` (edit — `decided_by`, authoritative).
- `addons/event_queue_manager/runtime/eq_order_explanation.gd` (new — EQOrderExplanation, core).
- `addons/event_queue_manager/editor/debug_inspector.gd` (new — EQDebugInspector, ui).
- `test_project/tests/runtime/test_eq_order_explanation.gd` (new — data model, sync).
- `test_project/tests/ui_headless/test_debug_inspector.gd` (new — inspector via collector, UI phase) + `run_ui_metrics.gd` (edit — invoke it).
- `tools/check_api_surface.py` + `docs/design/API_SURFACE.md` (+EQOrderExplanation core, +EQDebugInspector ui).
- `tests/golden/api_surface.json` — re-baselined (explicit `--update`): +`EQOrderExplanation`, +`EQDebugInspector`, +`EQOrdering.decided_by`. Additive only.

## Acceptance result — met

| acceptance | result |
|---|---|
| for a selected event, UI explains tick/priority/sequence/tie-break reason | inspector `select(entry, predecessor)` renders one row per factor (tick/priority/order) + deciding-factor mark |
| rendered from structured explanation data (explanation-as-data) | `EQOrderExplanation.factors` = [{key,value,rank,direction}]; `decided_by` is a key; UI maps keys→fixed labels/icons |
| not free-form strings | the runtime emits keys+integers only; the inspector's labels are fixed key names, not generated prose; values are integers (no float) |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0)
  [run_all] files=40 checks=578 failures=0   (+29: explanation data model + inspector)
  [api-surface] ok (golden re-baselined: +EQOrderExplanation, +EQDebugInspector, +decided_by)
```

## Design notes (no shrink)

- **`decided_by` is authoritative, not a parallel reimplementation.** It mirrors
  `less_than`'s exact key precedence in the same file; `EQOrderExplanation` and the
  existing `EQDebugOverlay` both consume it. A test asserts `less_than(a,b)` agrees
  with `decided_by(a,b)` so the explanation cannot drift from the sort.
- **Explanation is genuinely data.** Factors carry `{key, value, direction}` — no
  sentence is ever produced by the runtime. The inspector owns the key→short-label
  map (presentation), keeping prose out of the model. Asserted: each factor has a
  structured value+direction; `to_dict` stays compatible with `EQDebugOverlay`'s
  `{actor, decided_by}` dicts, so the EQM-083 overlay is now fed by this producer.
- **Deciding factor is marked non-textually**: the deciding `cause_icon` is full
  opacity + `ui_decided` meta + tooltip; others dimmed. State by modality, not text.
- **Inspector through the same harness**: fed to the EQM-087 collector; asserts no
  debug leakage / no boolean-text / integer values — the real surface passes the
  same metrics as the synthetic scenarios.

## UX path reduction

- Added: `EQOrderExplanation` (core), `EQDebugInspector` (ui), `EQOrdering.decided_by`.
  Narrowed: one authoritative decider; explanation is a closed factor set; inspector
  has empty/selected states only. Residual: tie_break beyond `sequence` (config's
  `actor_id` tie-break is realized via sequence assignment) is not a separate factor —
  noted; `sequence` is the effective final tie-break the order actually uses.

## Deviations

- None. The inspector reuses the established projection-first + ui_metric metadata
  pattern (EQM-090); explanation logic stays in the runtime, rendering in the editor.

## Repair-now / follow-up

None. Next: EQM-092 (Action Resolution demo template generator) — creates project
assets (not hidden sample defaults), generated demo uses reservation/trigger/
presentation APIs. Depends on EQM-091 + EQM-082 (both complete). Template/sample
separation is design-core → orchestrator-direct.
