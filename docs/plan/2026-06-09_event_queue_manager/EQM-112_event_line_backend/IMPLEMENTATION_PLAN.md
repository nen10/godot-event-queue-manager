# EQM-112 IMPLEMENTATION_PLAN — event-line backend

## Scope

SEM §4.3/§4.6/§4.7/§12.1 の backend 実装 (coverage rows: event-line-backend, sweep-rule-registry, progression-budgets)。pipeline 統合・snapshot v2 組込みはしない (EQM-113/117)。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_event_lines.gd` (new, L3)
- `test_project/tests/core/test_eq_event_lines.gd` (new)
- `test_project/tests/performance/test_eq_event_line_budget.gd` (new)
- `tools/check_api_surface.py` / `docs/design/API_SURFACE.md` / `tests/golden/api_surface.json` (L3 追加, 明示 --update)
- `docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md` (3 rows flip)

## 実装 steps

1. EQEventLines: table + issue/issue_counter/advance/re_rate/poll_tick/sync_primary/derive_watched/ctx_lines + faults + trace 記録。
2. sweep rule registry: register/run (登録順 × actor_id 昇順)/names。
3. to_dict/from_dict (id 昇順、callable 不含)。
4. 機能 test (順序・sparse・fault・roundtrip・EQConditionEval 統合)。
5. 予算 test (Q43: 300 watched lines poll / 200 actors sweep、粗い guard)。
6. API surface (L3 tag 初導入) → --update。
7. coverage flip → queue → self-review → commit。

## Test path

`./tools/test.sh`。golden 更新は api_surface のみ (明示 flag)。

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| EQConditionEval ctx 契約 | key 名 (lines) の不一致 | 統合 test (CT 閾値到達) |
| L3 leak gate | L0/L1 署名への型露出 | api-surface leak detector (standalone class で回避) |
| 走査順決定性 | 挿入順依存 | 挿入順入替 test + roundtrip 後同結果 |
| 予算 test の flake | CI 環境差 | EQM-102 と同様の粗い上限 (宣言予算×margin) |

## Completion checklist (planned)

- [ ] EQEventLines + tests + budget test green
- [ ] api-surface ok (L3 tag) / contract-coverage 3 rows flip
- [ ] queue proof / self-review / commit
