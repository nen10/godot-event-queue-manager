# EQM-138 UX — unchanged reaction behavior, lower candidate assembly cost

## User goal

game developerがwildcard反応を多く宣言しても、既存のarm順、発火結果、trace、save/loadを
変えずにsweepの候補構築コストが不要なsortで増えない。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. public cache/index tuning API | low | high | high | reject | derived state管理をconsumerへ漏らす |
| B. private stable merge | high | low | medium | adopt | caller操作なしで同じ結果をより少ないworkで返す |
| C. wildcardを制限するauthoring rule | low | high | low | reject | gameplay表現をengine都合で狭める |
| D. elapsed ratioをportable SLA化 | low | high | low | reject | host noiseをcorrectness gateに混ぜる |

## Experience steps

1. callerは従来どおりreactionをarmし、condition targetを変更できる。
2. resolved event sweepは従来と同じglobal arm orderで候補を評価する。
3. target-only、wildcard-only、mixed、retarget後のfired occurrenceは既存結果と同一。
4. performance laneだけがlegacy sortとstable mergeのelapsed/workを報告する。

Public API、resource schema、snapshot、trace recordは変更しない。
