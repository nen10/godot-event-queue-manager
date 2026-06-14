# EQM-033 UX

利用者 = HUD (EQM-083) / AI planner。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. predict_turns(runtime, n) 非破壊 | high | low | low | adopt | HUD が次 N を表示しても live を壊さない。 |
| B. branch() で hypothetical | high | low | low | adopt | AI が act-now vs wait を比較。discard で live 不変。 |
| C. prediction == actual を保証 | high | low | low | adopt | 表示順 = 実順序 (projection integrity の基盤)。 |
| D. predict が live を pop | low | high | low | reject | 純粋性違反。 |

## User goal

`EQPrediction.predict_turns(runtime, n)` で次 N turn の順序を得ても live queue は一切変わらず、予測は実際の進行と一致する。`branch()` で候補 action を当てた仮想進行を比較でき、捨てれば live は不変。

## Operation steps

1. `var order := EQPrediction.predict_turns(manager.runtime(), 5)` → 次 5 turn の actor 順。
2. live queue は不変 (snapshot before == after)。
3. 比較: `var b := EQPrediction.branch(rt)`; b に候補 action を当てて virtual advance; 結果を比較; b を discard。

## 既存 UX との干渉

新規 EQPrediction (L0)。EQScheduler.snapshot/restore (EQM-012) と EQRuntime (EQM-022) を再利用。EQSnapshot に equals 追加。
