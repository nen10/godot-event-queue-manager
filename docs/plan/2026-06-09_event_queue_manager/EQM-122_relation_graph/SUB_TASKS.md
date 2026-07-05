# EQM-122 SUB_TASKS — 関係グラフ backend

## Complexity

Class: C3 (bounded / integrated)。設計確定済み。新 class 1 + runtime 連動 1 点。

## Task resolution

| task 候補 | 採否 | 概要 |
|---|---|---|
| A. EQRelationGraph 新設 | 採用 | §13.1 (型宣言 / instance / 縫合 / trace / serialize) |
| B. invalidate_actor 連動 | 採用 | §13.1 (解消時規則経由) |
| C. 維持条件 sweep | 採用 | 宣言 sweep 名 + EQConditionEval 流用 |
| D. 展開消費 (§6.4) / snapshot table | 不採用 | EQM-123 / EQM-127 scope |

## Scheduled Task Audit

なし。
