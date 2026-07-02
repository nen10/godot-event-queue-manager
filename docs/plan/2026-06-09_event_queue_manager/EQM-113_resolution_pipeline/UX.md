# EQM-113 UX — 解決 pipeline 統合

user goal: L2 開発者が「宣言した効果は必ず結線され、反応・失効・離脱のすべてが trace で説明される」単一の解決サイクルを得る。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. 5-step pipeline + named effect linkage | high | medium | high | adopt | Q31 確定。chunk/save/trace が 1 契約に結線される |
| B. effect callback 必須化 | medium | high | medium | reject | Q31 reconciliation で任意項目確定 (L0/L1 を単純なまま保つ) |
| C. fired reaction の in-place 解決維持 | low | high | low | reject | Q32 確定。三面モデル不変条件違反 |
| D. expiry の sweep 数値評価のみ (event 化なし) | medium | medium | low | reject | Q40 確定 (推奨案 = event 化)。timeline/trace 可視が優先 |

## Operation steps

1. 起動時に `runtime.register_effect(&"counterattack", callable)` を登録し、`EQActionDefinition.effect_name` で宣言する (空なら effect なし解決)。
2. `EQReservationRuntime.submit()` → `resolve_next()` で解決。効果 records は chunk 経由で `last_drained` に出る (毎解決後 chunk 空 = save 可)。
3. 時間駆動の進行は `step_tick()` (poll + sweep rules + 条件評価)。条件成立した予約は成立 tick を due として自動 push。
4. actor 離脱は `invalidate_actor(actor_id)` (bridge 経由なら自動)。trace の `closed_by` で全終了理由が読める。

- 採用 UX: 宣言 linkage / schedule 化 cascade / event 化 expiry。
- 廃止 (hack/旧): `fire_cascade` in-place 解決 (削除)、trigger duration の silent 削除 (event 化で置換)。
- 干渉: EQM-051/052 の既存 resolve 挙動は維持 (既存 test で保証)。
