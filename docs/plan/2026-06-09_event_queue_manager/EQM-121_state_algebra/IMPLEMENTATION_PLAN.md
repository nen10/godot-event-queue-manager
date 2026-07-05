# EQM-121 IMPLEMENTATION_PLAN — 状態代数 backend

## Scope

SEM v1.2 §5.7 (inv ペア / 共存規則 / wrapping / 寿命合成 acceptance) + §4.8 (rate modifier-stack) の backend 実装 (coverage rows: state-algebra, rate-modifier-stack)。pipeline 統合 (§6.4 の展開・変換) は EQM-123、snapshot v3 table 化は EQM-127。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_state_algebra.gd` (new, L3)
- `addons/event_queue_manager/runtime/eq_event_lines.gd` (modifier-stack を additive 追加)
- `test_project/tests/core/test_eq_state_algebra.gd` (new)
- `test_project/tests/core/test_eq_event_lines.gd` (modifier test 追加)
- `test_project/tests/run_all.gd` (登録)
- `tests/golden/lifetime_composition.trace.jsonl` (new golden — 寿命 3 種、orchestrator が --update-golden で baseline)
- `tools/check_api_surface.py` 系 golden (L3 追加、明示 --update + doc note)
- `docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md` (2 rows flip — orchestrator)

## 実装 steps (P2 委譲: codex 実装、orchestrator gate)

1. EQEventLines: `modifiers` (ADD|OVERRIDE, 決定的採番 id) + effective_rate 再計算 + base_rate 書き換えとしての re_rate + poll は実効 rate 使用 + trace (`modifier_id` field) + to_dict/from_dict additive。
2. EQStateAlgebra (new): inv ペア宣言 (CANCEL/EXCLUDE/COEXIST)、CANCEL = 符号付き 1 軸 counter line、EXCLUDE = 解除→付与、COEXIST = 独立 line;wrapper 合成 (wrap 順 / LIFO unwrap / trace);to_dict/from_dict。
3. 寿命 3 種 acceptance scenario (スタック系 = decremental counter / ターン系 = expiry / 現象 = ターン条件なし) を既存 reservation runtime で組み、golden trace 化。
4. Gate: `./tools/test.sh` (api-surface / contract-coverage 含む) → coverage flip → self-review → commit。

## Test path

`./tools/test.sh`。新規 golden は `--update-golden lifetime_composition` (orchestrator 実行、self-review 記録)。
