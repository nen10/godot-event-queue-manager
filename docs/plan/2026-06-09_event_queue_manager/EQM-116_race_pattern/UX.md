# EQM-116 UX — race pattern

user goal: 「いずれかの条件で発動する効果」(OR 解決) を、効果の重複適用や敗者の silent 消滅なしに宣言でき、開発中は候補群として一目で追える。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. `submit_race(members)` (発行糖衣 + 帳簿) | high | low | low | adopt | Q18 確定の race pattern を最短 API で提供 |
| B. solve_conditions に OR mode を追加 | medium | high | medium | reject | Q18/Q29 確定に反する (solve は AND のみ)。概念が二重化する |
| C. 3 表示の完全実装 (presentation 集約 UI) | medium | medium | high | reject (最小実装) | in-game は勝者の効果しか流れない構造で既に充足。残りは trace + overlay 集約で足りる |

## Operation steps

1. 同一 `effect_name` の定義を条件違いで複数作り、`rr.submit_race([resA, resB])` で発行する。
2. 先に条件が成立した member が解決し (同時成立は §7.1 hook → 発行順)、効果は 1 回だけ適用される。
3. 敗者は `closed_by: race_lost` として trace に残る (EQM debug)。overlay は race 候補群を 1 行に集約して表示する (game-dev debug)。

- 採用 UX: 発行糖衣 + trace 可視 + overlay 集約。廃止/保留: なし。
- 干渉: overlay の既存 rows() 契約は不変 (集約 row は別 role)。
