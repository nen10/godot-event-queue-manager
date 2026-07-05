# EQM-121 SUB_TASKS — 状態代数 backend

## Complexity

Class: C3 (bounded / integrated)。設計は SEM v1.2 で確定済み、判断は残っていない。
実装 2 面 (event-line 拡張 + 新 class) + acceptance golden 1 本。

## Task resolution

| task 候補 | 採否 | 概要 |
|---|---|---|
| A. modifier-stack (EQEventLines additive) | 採用 | §4.8 |
| B. EQStateAlgebra 新設 | 採用 | §5.7 (inv ペア / wrapping / serialize) |
| C. 寿命 3 種 acceptance golden | 採用 | Q46 (既存語彙のみ、新 primitive なし) |
| D. pipeline 統合 / snapshot table | 不採用 | EQM-123 / EQM-127 の scope |

## Scheduled Task Audit

なし (follow-up が出たら queue の Dynamic follow-up area へ)。
