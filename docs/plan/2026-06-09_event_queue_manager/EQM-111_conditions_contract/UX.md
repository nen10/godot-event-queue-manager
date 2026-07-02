# EQM-111 UX — conditions 契約実装

user goal: game 開発者が「条件つき予約」の条件を Resource として宣言し、editor/.tres で保存でき、その評価規則 (level AND / OR / invalidation-wins) が予測可能である。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. EQConditionSpec (typed Resource, 3 type) | high | low | medium | adopt | inspector で宣言でき、狭い入力クラス (UX_PATH_REDUCTION) |
| B. 自由 GDScript predicate を条件に直接持たせる | medium | high | low | reject | save を跨げず決定性検証不能。named registry のみ許可 |
| C. 条件式 DSL (文字列) | medium | high | high | reject | 広い入口・完走非保証。Q23 ガードレール違反 |

## Operation steps

1. inspector で `EQActionDefinition.solve_conditions / invalidation_conditions` に `EQConditionSpec` を追加し、type と parameter を設定する。
2. predicate 型を使う場合のみ、起動時に `runtime.register_predicate(name, callable)` を 1 行書く。
3. 挙動は `EQConditionEval` の決定的な規則 (level AND / OR / invalidation-wins / closed_by) に従い、trace で説明される (pipeline 統合は EQM-113)。

- 採用 UX: 宣言的 Resource + named registry。
- 廃止/保留: なし (既存 duration/rumination は糖衣として維持)。
- 干渉: EQCondition (trigger 照合) と名前が近い — class docstring と manual (EQM-119) で役割を区別する。
