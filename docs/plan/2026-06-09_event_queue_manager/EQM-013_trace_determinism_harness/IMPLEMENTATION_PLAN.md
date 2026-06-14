# EQM-013 IMPLEMENTATION_PLAN

## Scope

canonical trace export (`EQTrace`) と determinism harness (golden approval + property/metamorphic tests) を確立する。後続 kind の追加余地を残す。policy/reservation/presentation の trace kind は含めない (それぞれの phase が足す)。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_trace.gd` — `EQTrace`: 汎用 `record` + `record_resolved` + canonical `to_jsonl` (再帰 sort key encoder) + static `trace_run`。
- `tools/test.sh` — Godot runner へ `EQ_RUN_OUT` (run 出力 dir 絶対パス) を export (失敗時 actual trace の出力先)。既存 `--update-golden` plumbing はそのまま利用。
- `test_project/tests/golden/core_scheduler_basic.trace.jsonl` — 固定シナリオの golden fixture (初回 baseline は `--update-golden` で生成)。
- `test_project/tests/core/test_eq_trace_golden.gd` — golden approval gate + 失敗時 actual 出力。
- `test_project/tests/core/test_eq_trace_properties.gd` — replay determinism / permutation invariance / snapshot continuity / decided_by 整合 / open-kind 拡張性。

## 実装 steps

1. `EQTrace` を作成 (canonical encoder、record/record_resolved/to_jsonl/trace_run)。
2. `tools/test.sh` に `EQ_RUN_OUT` export を追加。
3. property test を作成。
4. golden test を作成。
5. `./tools/test.sh --update-golden core_scheduler_basic` で初回 baseline 生成。
6. 通常 `./tools/test.sh` で exact match + 全 property pass を確認。

## Test path

- 通常: `./tools/test.sh` → import → runner → golden exact match + property pass、`failures=0`、exit 0。
- 更新: `./tools/test.sh --update-golden core_scheduler_basic` → golden 再生成 (明示時のみ)。

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| EQOrdering (EQM-010) | tie_break が comparator と乖離 | decided_by の due_tick/priority/sequence/terminal 分岐を assert |
| EQScheduler pop/peek (EQM-011) | resolution 順/clock 誤り | golden の i/tick/seq 列が固定シナリオと一致 |
| EQ snapshot/restore (EQM-012) | 中断で trace ずれ | snapshot continuity: 中断 trace == 無停止 trace (byte) |
| canonical encoder | 非決定 serialize / float 混入 | 2回生成 byte 一致、float guard、key 固定順 |
| open kind schema | 後続 kind で harness 改修要 | future kind (`event_line_progressed` 様) を record→安定出力 assert |
| golden 承認フロー | 自動更新 regression | 通常 run read-only 比較、更新は flag のみ |

## Completion checklist

- [ ] same-seed replay が byte 一致。
- [ ] permutation invariance (同 entry 集合は挿入順非依存)。
- [ ] snapshot continuity (中断 trace == 無停止 trace)。
- [ ] golden exact match、更新は `--update-golden` flag のみ。
- [ ] trace-kind schema が open (future kind を改修なしで追加できることを test で証明)。
- [ ] tie_break.decided_by が comparator と一致。
- [ ] `./tools/test.sh` PASS。
