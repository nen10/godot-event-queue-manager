# EQM-011 IMPLEMENTATION_PLAN

## Scope

scheduler の push/pop/peek/cancel/reschedule を、差し替え可能な backend contract の背後で実装する。snapshot (EQM-012) / trace (EQM-013) / policy は含めない。current_tick・sequence・generation という scheduler state を確立し EQM-012 が serialize できる形にする。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/backends/eq_backend.gd` — `@abstract class_name EQBackend`。contract メソッド宣言 + doc。
- `addons/event_queue_manager/runtime/backends/eq_sorted_array_backend.gd` — `EQSortedArrayBackend extends EQBackend`。`bsearch_custom` 順序挿入。
- `addons/event_queue_manager/runtime/eq_scheduler.gd` — `EQScheduler`。採番 + lazy invalidation + current_tick。
- `test_project/tests/core/test_eq_scheduler.gd` — push/pop/peek/cancel/reschedule/empty/lazy/current_tick。
- `test_project/tests/core/test_eq_backend_contract.gd` — sorted-array と naive backend の metamorphic 一致 (contract 抽象の証明)。

## 実装 steps

1. `EQBackend` を `@abstract` で定義 (insert/pop_min/peek_min/ordered/size/is_empty/clear)。
2. `EQSortedArrayBackend` を実装 (sorted insert via bsearch_custom, pop_front)。
3. `EQScheduler` を実装 (push 採番、pop で stale skip + current_tick 前進、peek 非破壊 filter、cancel/reschedule で generation 操作)。
4. scheduler tests + backend contract metamorphic test を作成。
5. `./tools/test.sh` PASS を確認 (import pass 込み)。

## Test path

- `./tools/test.sh` → import pass → headless runner。
- 期待: 既存 9 checks + EQM-011 の新 checks が全 pass、`failures=0`、exit 0。

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| EQOrdering (EQM-010) | 順序契約の再利用が破れる | scheduler の pop 順が EQOrdering と一致 (peek/pop 順 assert) |
| backend contract 抽象 | scheduler が特定 backend に依存 | naive backend で同一 pop 順 (metamorphic) |
| lazy invalidation/generation | stale を live と誤認 / 二重 pop | cancel→pop skip、reschedule→新順序、size 整合 |
| 採番 (event_id/sequence) | 衝突 / 拒否時の状態汚染 | 連番性、負 tick 拒否で counter 不消費 |
| `@abstract` (Godot 4.6) | parse 不可なら gate FAIL | test.sh の parse-error guard が即検出 → fallback は push_error base |

## Completion checklist

- [ ] push が event_id を返し、負 tick は -1 (counter 不消費)。
- [ ] pop が EQOrdering 順、空で null、current_tick が popped.due_tick へ前進。
- [ ] peek_next / peek(N) が非破壊で live のみ返す。
- [ ] cancel by event_id (lazy)、未知 id は false、size 整合。
- [ ] reschedule = 同 id・新 sequence・gen+1、旧 entry stale、payload/kind 維持。
- [ ] sorted-array と naive backend が同じ pop 順 (contract 抽象の証明)。
- [ ] `./tools/test.sh` PASS。
