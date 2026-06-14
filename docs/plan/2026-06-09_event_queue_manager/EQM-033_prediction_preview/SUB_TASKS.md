# EQM-033 SUB_TASKS

## Complexity

Class: C3
Reason:
- prediction purity (live state 不変) という不変条件を確立し、HUD(EQM-083)/AI が依存する。
- hypothetical branch (snapshot→virtual advance→discard) API。watched-set 独立性 (Q26, 前方互換) の構造を持つ。

Required artifacts: Complexity header / Task Resolution / UX / POLICY / IMPLEMENTATION_PLAN (dependency/test matrix)。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQPrediction.predict_turns(runtime, n) | 次 N turn を非破壊で返す | adopt | branch して policy で N 回 virtual advance。live 不変。 |
| EQPrediction.branch(runtime) | 使い捨て runtime copy | adopt | scheduler snapshot restore + actor data copy。discard で live 不変。 |
| prediction purity | live snapshot before==after | adopt | EQSnapshot.equals で検証。principle 17。 |
| prediction == actual | 予測が実進行と一致 | adopt | predict 列 == 実 advance 列。 |
| act-now vs wait 比較 | branch に候補 action を当てて比較 | adopt | branch×2 (normal/heavy) で順序差、live 不変。 |
| watched-set 独立性 (Q26) | per-step 再評価、N 非従属 | adopt | predict は 1 step ずつ pop+reschedule (precompute しない)。event-line 実装は Phase4/5。 |
| 予測が live を pop する | — | reject | 純粋性違反。branch のみ操作。 |

## Scheduled Task Audit

新規 scheduled task なし。次の依存解放は EQM-034 (CTB sample battle)。runtime timeline HUD は EQM-083 が EQPrediction を projection。full hypothetical-branch (transaction/rollback) は Phase7 (EQM-070+)。
