# EQM-111 SUB_TASKS — conditions 契約実装

## Complexity

Class: C3
Reason:

- resources / runtime / error taxonomy / tests / API surface golden にまたがるが、単一の完了境界 (条件契約が宣言・検証・評価できる)。
- 状態は Resource + 純粋評価器で、runtime 統合 (pipeline) は EQM-113 が持つため干渉は API surface のみ。

Required artifacts: C2 + dependency/test matrix + state/invariant table (POLICY.md / IMPLEMENTATION_PLAN.md)。

## Task resolution

| task 候補 | 目標/UX | 採否 | 概要 |
|---|---|---|---|
| A. EQConditionSpec Resource | SEM §5.6 の authoring 単位 | 採用 | LINE_THRESHOLD / COUNTER / NAMED_PREDICATE + relative threshold + condition_id |
| B. EQConditionEval 純粋評価器 | SEM §5.4 (level AND / OR / invalidation-wins) | 採用 | bind (相対→絶対, counter→line 化) + term/solve/invalidation/decide。pipeline 非依存で test 可能 |
| C. named predicate registry | SEM §5.5 | 採用 | EQRuntime instance 所在。未登録 = 安定 error。再登録は置換 (冪等 setup) |
| D. duration/rumination 糖衣の正規化 | SEM §5.6 | 採用 | `normalized_conditions()`: duration → relative LINE_THRESHOLD(primary, condition_id=duration)、rumination → COUNTER(start=rumination+1, condition_id=reaction_count) |
| E. pipeline への評価組込み | — | 不採用 (EQM-113) | coverage row resolution-pipeline の scope。ここでやると task 境界が崩れる |
| F. effect_name field 追加 | — | 不採用 (EQM-113) | §6.1 宣言 linkage は pipeline の error 契約と同時に入れる |

Scheduled task: なし (E/F は既存 EQM-113 が owner)。
