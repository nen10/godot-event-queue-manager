# EQM-126 IMPLEMENTATION_PLAN — 操作フェーズ再帰 + ループ解消

## Scope
SEM v1.2 §8.4 (coverage: phase-recursion)。

## 変更対象ファイル
- `addons/event_queue_manager/runtime/eq_window.gd` (phase sub-checkpoint)
- `addons/event_queue_manager/runtime/eq_transaction.gd` (checkpoint 復元)
- `addons/event_queue_manager/runtime/eq_reservation_runtime.gd` (遷移履歴 + ループ検出 + 巻き戻し)
- `test_project/tests/transaction/test_eq_phase_rollback.gd` (new)
- `tests/golden/mirror_loop_rollback.trace.jsonl` (new — 水鏡の再帰入力ループ)
- coverage row flip (orchestrator)

## 実装 steps (P2 委譲)
1. window draft 内の順序付き phase checkpoint (決定的 id、named)。
2. フェーズ遷移履歴 + 同一フェーズ再訪検出 = 最小 cycle。
3. 解消: ループ開始 checkpoint へ working-copy 巻き戻し + cycle 上の鏡面入力解除 + `phase_rolled_back` trace (span + cleared inputs)。
4. 水鏡 golden。

## Test path
`./tools/test.sh`。新規 golden は --update-golden mirror_loop_rollback。
