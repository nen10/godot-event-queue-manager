# EQM-119 UX — L2 authoring surface

user goal: 「反撃準備 — 3 回 or 5 ターンのどちらかで終わる」を、コードを書かずに asset として宣言でき、どちらで終わったかが trace で読める。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. 糖衣 2 field (rumination/duration) の .tres 宣言 | high | low | low | adopt | 最頻ケースが 2 int。§5.6 の意図そのもの |
| B. EQConditionSpec 明示宣言を最頻ケースにも強制 | low | medium | low | reject | 単純な場合を複雑にする (Q42 で糖衣維持を確定済み) |
| C. 専用 authoring dialog | medium | medium | high | reject | dock mounting 自体が v1.x follow-up。inspector で既に宣言可能 |

## Operation steps

1. inspector で `EQActionDefinition` resource を作り、kind=REACTION_PREPARATION、duration=5、rumination=2、effect_name を設定して .tres 保存 (コード 0 行)。
2. game 側は起動時に `register_effect(&"counterattack", ...)` を 1 行、arm 時に `submit(load(...), condition)` を 1 行。
3. 3 回使い切れば `closed_by: reaction_count`、5 ターン経てば `closed_by: duration` が trace に出る。deadline を無くすなら duration=-1 (∞) にするだけ。

- 採用 UX: 宣言的 asset + closed_by の説明可能性。
- 廃止/保留: なし。干渉: 既存 dogfood golden 不変 (additive)。
