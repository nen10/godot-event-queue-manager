# EQM-137 IMPLEMENTATION PLAN — reaction-condition contract hardening

## Scope

wrong-type reaction conditionを全mutation前に拒否し、runtime/engine/indexの各公開境界を
fail-closed化する。EBS側では誤契約testとrunner false-greenを修正し、consumer repo内の
development log/design docsへ標準形を残す。

## Target files

EQM:

- `addons/event_queue_manager/runtime/eq_error.gd`
- `addons/event_queue_manager/runtime/eq_reservation_runtime.gd`
- `addons/event_queue_manager/runtime/eq_trigger_engine.gd`
- `addons/event_queue_manager/runtime/eq_trigger_index.gd`
- `docs/design/ERROR_CONTRACT.md`
- trigger/runtime/resource tests and API surface golden when required

Consumer proof (EBS repo, committed separately only if its repo policy/user requests it):

- `integration/eqm/ebs_eqm_bridge.gd`
- `tests/integration/test_acceptance_stubs.gd`, `test_eqm_bridge.gd`
- `tools/test.sh`, `tools/test_performance.sh` or a shared checked runner helper
- `docs/design/EQM_ACCEPTANCE_INSTANCES.md`
- `docs/development_log/` and `DEPS.md` after current EQM revision passes

## Implementation steps

1. append-only error code/metadata/docを追加する。
2. submit preflightをreservation validation直後へ追加し、rejection trace + fault + `-1`で返す。
3. engine/indexのarm/addを明示結果付きにし、成功後だけcanonical/derived stateを更新する。
4. dev/shipped、direct low-level、valid continuationの回帰testを追加する。
5. EBS bridgeでwrong typeをEQM呼出前に拒否し、R04 testをnormalized event tag + trigger
   `EQCondition`の標準形へ直す。reaction FIREへのdefinition solve適用は別taskとする。
6. EBS GUT runnersをSCRIPT ERROR fail-closedにし、誤契約を説明するEBS docsを更新する。
7. EQM full regression + performance、EBS regression + performance + packageを実行する。
8. self-review、queue/proof、DEPS verified revisionを更新する。

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| EQError append-only taxonomy | unknown code loses recoverability | metadata test + ERROR_CONTRACT |
| submit preflight ordering | issued meta/effect/status partially mutates | fresh reservation field audit |
| trigger engine/index | invalid sequence consumption changes later order | direct invalid then valid sequence/order test |
| resilience modes | shipped halts or dev hides fault | two-mode test + continuation |
| normal trigger lifecycle | return-type/internal reorder changes semantics | existing trigger regression + golden/full gate |
| EBS bridge | runtime rejection still reported success | explicit wrong-type integration test |
| EBS GUT runner | SCRIPT ERROR exits green | log-guard negative self-check + normal suites |
| performance separation | correctness fix leaks into speed lane | both explicit commands; discovery counts remain separate |

## Completion checklist

- [x] Wrong types create no ghost state in runtime, engine, or index.
- [x] Stable fault/rejection trace and dev/shipped continuation are tested.
- [x] Valid trigger lifecycle and normal goldens remain unchanged.
- [x] EBS standard form and runner guard are documented inside EBS.
- [x] EQM regression/performance and EBS regression/performance/package pass.
- [x] Self-review has no repair-now item; queue proof and dependency sweep are updated.
