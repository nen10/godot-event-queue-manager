# EQM-020 Self-Review 2026-06-15

Pattern: P0 (orchestrator-direct). Repair: 0 (gate green first run).

## Execution summary

Established the error taxonomy and the first configuration Resources. `EQError` is the single authority for stable namespaced codes → recoverability class / severity / surfacing; `EQValidation` aggregates issues and reports validity. `EQPolicy` is the base extension point (concrete subclasses arrive Phase 3); `EQConfig` holds the policy + tie_break + schema_version and validates with explicit codes — never a silent default. `ERROR_CONTRACT.md` documents the taxonomy and the recoverability → dev/shipped mapping that EQM-022 will act on.

## Changed files

- `addons/event_queue_manager/runtime/eq_error.gd` — `EQError`: `Recoverability{CONTRACT_VIOLATION,BUDGET_EXCEEDED,RESOURCE_INVALID,EXTERNAL_STATE}` (mirrors RUNTIME_RESILIENCE_POLICY §1), `Severity{WARNING,ERROR}`, append-only codes, `recoverability_of`/`severity_of`/`surfaces_in`/`is_known` (unknown code → strictest default).
- `addons/event_queue_manager/runtime/eq_validation.gd` — `EQValidation`: `add`/`is_valid`/`errors`/`warnings`/`codes`/`has_code`; tags each issue from the taxonomy.
- `addons/event_queue_manager/resources/policies/eq_policy.gd` — `EQPolicy` base (extension point; `policy_name`).
- `addons/event_queue_manager/resources/eq_config.gd` — `EQConfig`: `policy`/`tie_break`/`schema_version`, `validate() -> EQValidation` (missing/base/ambiguous/unknown), base-instance detected via `get_script() == preload(eq_policy.gd)`.
- `docs/design/ERROR_CONTRACT.md` — taxonomy doc (codes table, recoverability→dev/shipped, severity/surfacing, stability promise).
- `test_project/tests/resource/test_eq_error_taxonomy.gd` — code metadata, unknown-code strict default, EQValidation aggregation.
- `test_project/tests/resource/test_eq_config.gd` — valid config, 4 rejection tests, `.tres` roundtrip.

## Acceptance result — met

| acceptance | result |
|---|---|
| Resource saved/loaded | `.tres` roundtrip preserves policy sub-resource, tie_break, schema_version |
| missing policy → explicit validation | `POLICY_MISSING`, is_valid false |
| ambiguous tie-breaker → explicit validation | unset → `TIE_BREAK_AMBIGUOUS` (and unknown → `TIE_BREAK_UNKNOWN`), is_valid false |
| contracts follow `EVENT_MODEL_SEMANTICS.md` | int domain (§12), tie_break = deterministic total set; schema_version aligns with EQM-012 |
| error taxonomy in `ERROR_CONTRACT.md` used by validation | `EQConfig.validate` emits taxonomy codes; `EQValidation` carries recoverability/severity from `EQError` |
| recoverability classes map to dev/shipped two modes | `Recoverability` enum mirrors RUNTIME_RESILIENCE_POLICY §1; ERROR_CONTRACT.md §2 documents the dev/shipped behaviour (the *toggle* is EQM-022) |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=9 checks=132 failures=0
```

Gate (§4 resource/API): roundtrip + validation green. Layer-aware API surface gate lands in EQM-023.

## UX path reduction (self-review checklist)

- **Added entries**: `EQConfig.policy` (single accepted class = concrete EQPolicy subclass), `EQConfig.tie_break` (known total set).
- **Narrowed**: policy slot rejects null + base instance; tie_break rejects unset + unknown — all as explicit codes with rejection tests.
- **Residual fallback**: none. No silent sample/default policy path exists.

## Deviations

- Two helper files beyond the listed targets: `eq_error.gd` (the taxonomy needs a code home) and `eq_validation.gd` (the `validate()` return type). Justified by the acceptance ("error taxonomy used by validation") and reused by EQM-021/022. Recorded.

## No sample-only completion

All acceptance rests on direct validation/roundtrip/taxonomy assertions. No bundled sample.

## Repair-now / follow-up

None. Note: `EQSnapshot.Load` (EQM-012) remains its own enum, not yet folded into `EQError`; ERROR_CONTRACT.md §4 records that EQM-022 may unify it without renaming — not blocking. Next: EQM-021 (actor state / action result / registry) unblocked; it will reuse `EQError`/`EQValidation` for duplicate-id rejection and action-result validation, and `actor_id` uniqueness backs the `tie_break = &"actor_id"` totality assumption.
