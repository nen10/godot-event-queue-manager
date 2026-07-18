# EQM-136 SUB_TASKS — production trigger index and performance lane

## Complexity

Class: C4

Reason:

- production reaction lifecycle、Resource mutation、save/load continuity、test discovery processを同時に扱う performance path である。
- correctness proof と wall-clock measurement を分離しつつ、既存の発火順・rumination・expiry ownershipを一切変えない必要がある。

Required artifacts:

- Task Resolution / Scheduled Task Audit
- UX / POLICY / IMPLEMENTATION_PLAN
- Fallback / Mirror Handling、State / Invariant Table、dependency / test matrix
- self-review + regression/performance 両laneの証拠

## Task Resolution Candidate Matrix

| candidate | decision | reason |
|---|---|---|
| callerが`EQTriggerIndex`を別管理する | reject | 二重管理と同期漏れをconsumerへ転嫁する。 |
| engine内部へ派生cacheとして統合する | adopt | 既存arm/resolve APIのまま全consumerが恩恵を得る。 |
| indexをsnapshotへ保存する | reject | canonical armed tableと競合する第二の真実になる。 |
| armed配列順からload時にindexを再構築する | adopt | schema/API変更なしでcontinuationを保存できる。 |
| indexだけでfireを確定する | reject | indexは候補filterであり、tag/source/custom predicateは`matches()`で判定する。 |
| arm後の`match_target`変更を禁止または無視する | reject | public Resourceの既存動的挙動を暗黙に狭める。 |
| `EQCondition.changed`で同一sequenceを再bucketする | adopt | false negativeを防ぎ、既存arm orderを保存する。 |
| 毎sweepでexpiryのため全armed走査する | reject | target indexを接続してもend-to-end hot pathが残る。 |
| 次の有限期限cacheで境界時だけexpiry走査する | adopt | arm orderのexpiry観測を保ったまま通常sweepをO(1) gateにできる。 |
| wall-clockだけをhard gateにする | reject | CI/engine/hardware差でalgorithmic regressionとnoiseを区別できない。 |
| matches呼出数をhard gate、elapsedを独立laneで記録する | adopt | work reductionを決定的に証明し、時間も観測できる。 |
| event-line/relation/schedulerも同時最適化する | defer | 原因別measurementと小さいcompletion boundaryを失う。 |

## Scheduled Task Audit

本taskはtrigger matchingとtest分類を完結させる。event-line全line sort、relation全表scan、scheduler live-peek、trace retentionは既知だが、EQM-136の測定で支配的と証明される前に新taskを自動起票しない。実測が新たなblocking hot pathを示した場合だけDynamic follow-upへ追加する。

## Resolution

1. 通常回帰から`tests/performance/`を除外し、明示performance modeだけが収集する。
2. correctness/parityと時間閾値が混在する既存testを責務別に分割する。
3. `_armed`を正本、`EQTriggerIndex`とnext-expiry値を派生cacheとしてproduction engineへ統合する。
4. arm後target変更、duplicate arm、rumination、expiry、disarm、save/loadを含むparityを通常回帰で固定する。
5. actual production engineのcandidate work-countとelapsedをperformance laneで記録する。
