# EQM-071 IMPLEMENTATION_PLAN

## Scope

EQTransaction と EQActionResolutionPolicy を結線し wait-commit 境界を実装する。deterministic replay は EQM-072。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_transaction.gd` — commit 後 draft guard (draft_push/draft_cancel が _committed で no-op)。
- `addons/event_queue_manager/resources/policies/eq_action_resolution_policy.gd` — `wait_close(runtime, actor_id, result, transaction = null)`。
- `tools/check_api_surface.py` / `docs/design/API_SURFACE.md` — EQActionResolutionPolicy に wait_close 反映 (surface 更新)。
- `tests/golden/api_surface.json` — `--update`。
- `test_project/tests/transaction/test_eq_wait_commit_boundary.gd` — rollback-before-wait / wait commits + ready / commit guard / null transaction。

## 実装 steps

1. EQTransaction: draft_push/draft_cancel に `if _committed: return` guard。
2. EQActionResolutionPolicy.wait_close。
3. test。
4. `python3 tools/check_api_surface.py --update`。
5. `./tools/test.sh` PASS。

## Test path / gate

- §4 gate (transaction): immediate rollbackable before wait / wait commits draft + schedules ready / commit guard。
- §4 gate (API surface): EQActionResolutionPolicy 更新、no L3 leak。
- 期待: 既存 388 + 新 checks、api-surface ok、exit 0。

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| EQTransaction (EQM-070) | commit/rollback 不整合 | rollback で live 不変、commit で live=working |
| EQActionResolutionPolicy (EQM-052) | ready 予約欠落 | wait 後 ready turn が live に |
| PROJECT_PROFILE (transactional turns) | wait 前 commit | wait 前 draft + rollback 可 |
| API surface gate | 無断変更 | 明示 --update |

## Completion checklist

- [ ] immediate action が wait 前 rollback 可 (live 不変)。
- [ ] wait_close が draft を commit + ready 予約を schedule。
- [ ] commit 後 draft guard (no-op)。
- [ ] transaction=null で on_turn_finished のみ。
- [ ] golden 明示更新、`./tools/test.sh` PASS。
