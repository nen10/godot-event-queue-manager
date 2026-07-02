# EQM-119 SUB_TASKS — L2 authoring surface + dogfood/manual (Phase 11 最終)

## Complexity

Class: C3
Reason: 凍結受け入れ基準 (SEM §5.6) の証明 + dogfood/manual の複数文書更新。product code 変更なし (糖衣は EQM-111、pipeline は EQM-113 で実装済み — 本 task はそれを authoring 面から証明する)。

## Task resolution

| task 候補 | 目標/UX | 採否 | 概要 |
|---|---|---|---|
| A. 手書き .tres fixture (反撃準備) | SEM §5.6 凍結基準 | 採用 | `dogfood/action_resolution/counterattack_preparation.tres`: kind=REACTION_PREPARATION, duration=5, rumination=2 (= 3回 or 5ターン), effect_name — **GDScript 0 行の宣言** |
| B. dogfood へ L2 natural path を additive 追加 | queue acceptance | 採用 | `run_l2_trace()`: .tres load + `register_effect` + EQReservationRuntime pipeline。既存 `run_trace()` とその golden は不変 |
| C. 受け入れ test + golden `authoring_counterattack` | 「closed_by がどちらで閉じたか golden で可視」 | 採用 | 同一 trace に `closed_by: reaction_count` (3 回消尽) と `closed_by: duration` (5 ターン) の両閉路 + deadline ∞ 変種 (expiry event 非 schedule) |
| D. manual 更新 (EN + JA mirror) | 開発者導線 | 採用 | reservations.md: 条件宣言 (EQConditionSpec / 糖衣 / closed_by / named registries)。action_resolution.md: named-effect natural path + save 境界 |
| E. Q35 effect grouping の要否再評価 | declared follow-up の解消 | 採用 (defer 確定) | EQEffectRecord.tags で grouping 表現が既に可能・需要信号なし → v1.x 実装せず。判断を self-review + registry に記録 |
| F. 既存 dogfood run_trace() の L2 全面書き換え | — | 不採用 | 既存 golden を壊す。L0 手動配線の姿は「natural path 以前」の対照として価値が残る (manual で対比) |
| G. editor picker (Phase 9 資産の条件 UI) | — | 不採用 (follow-up 維持) | dock mounting 自体が v1.x follow-up (EQM-103 declared)。inspector の typed Resource 編集で宣言は既に可能 |

Scheduled task: なし (G は既存 declared follow-up に包含)。
