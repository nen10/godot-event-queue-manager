# EQM-070 IMPLEMENTATION_PLAN

## Scope

EQTransaction (working-copy draft / inspect / rollback / commit) を実装する。wait-commit + ready 予約は EQM-071、deterministic RNG は EQM-072。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_transaction.gd` — `EQTransaction` (L2)。
- `tools/check_api_surface.py` — LAYER_MAP に `EQTransaction: L2`。
- `docs/design/API_SURFACE.md` — L2 表に追記。
- `tests/golden/api_surface.json` — `--update`。
- `test_project/tests/transaction/test_eq_transaction.gd` (new dir) — draft/inspect/rollback/commit/live-unchanged。

(eq_snapshot.gd は既存 API で足りるため変更しない。)

## 実装 steps

1. EQTransaction: _live/_base/_working/_committed/_draft_log; draft_push/draft_cancel; working/draft/is_live_unchanged; rollback/commit/is_committed。
2. LAYER_MAP + API_SURFACE.md。
3. test。
4. `python3 tools/check_api_surface.py --update`。
5. `./tools/test.sh` PASS。

## Test path / gate

- §4 gate (transaction): draft 適用 / inspect / rollback / commit / live unchanged before commit。
- §4 gate (API surface): EQTransaction L2、no L3 leak。
- 期待: 既存 370 + 新 checks、api-surface ok、exit 0。

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| EQ snapshot/restore (EQM-012) | clone/昇格 不整合 | working clone == base、commit で live==working |
| EQSnapshot.equals (EQM-033) | 不変判定誤り | is_live_unchanged で live==base |
| PROJECT_PROFILE (transactional turns) | rollback 不徹底 | rollback で draft 完全破棄 |
| API surface gate | 無断変更 | 明示 --update、L2 |

## Completion checklist

- [ ] draft_push/draft_cancel が working に適用、live 不変。
- [ ] inspect (working/draft)。
- [ ] rollback で working=base, draft 空, live 不変。
- [ ] commit で live=working。
- [ ] EQTransaction L2、golden 明示更新。
- [ ] `./tools/test.sh` PASS。
