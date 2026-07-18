# EQM-141 SUB_TASKS — reaction FIRE conditions

## Complexity

Class: C4

Reason:

- trigger candidate selectionとdefinition solve/invalidationを二相で接続し、arm/ruminationの
  mutation境界を変える。
- arm時bind、COUNTER progression、expiry/actor invalidation、snapshot v8を同じlifecycleで
  整合させる必要がある。
- EQM単体回帰に加えてEBS R04 consumer proofを実FIREまで通す。

Required artifacts:

- Task Resolution / Scheduled Task Audit
- UX Candidate Matrix
- Fallback / Mirror Handling
- State / Invariant Table
- Dependency / Test Matrix

## Task Resolution

| candidate | value | decision | reason |
|---|---|---|---|
| A. `EQConditionSpec`をtrigger matcherとして扱う | 一つの引数 | reject | event candidateとlevel gateを混同し、indexとsnapshot契約を壊す |
| B. match時にarmを消費してからgate評価 | 既存engineを流用 | reject | WAIT/FAULTがfalse greenになりruminationを失う |
| C. non-mutating preview後にgateを評価し、RESOLVE時だけcommit | mutationを明示 | adopt | original armを保持したままWAIT/invalidation-winsを決定できる |
| D. 条件をFIRE occurrence生成後にbind | 実装局所 | reject | relative/counter anchorが毎FIREずれ、solveを二重評価する |
| E. authored条件をarm時に一度bindしarmed rowへ保存 | exact continuation | adopt | relative threshold、counter id、predicate nameを固定できる |
| F. named predicateへlive reservationを渡す | 情報量大 | reject | save可能なview契約に反する |

## Scheduled Task Audit

新しいscheduled taskは追加しない。EQM-141内でengine preview/commit、reaction gate、schema v8、
consumer proofまで閉じる。elapsed性能は意味論修理の合否へ混ぜず既存performance laneの回帰だけを
実行する。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| trigger index | `EQCondition|null`だけを索引化 | spec誤用再発 | wrong-layer rejection + engine/index regression |
| armed gate | solve/inv/counter idsはarm時に一度bind | triggerごとの再bind | false→true + counter id/save exactness |
| preview | reservation/sequence/fire_indexを読むだけ | status/rumination先行mutation | preview state equality |
| WAIT | arm/status/rumination/counterを不変にする | false green/使用回数消費 | repeated false then true |
| INVALIDATE | invalidation-winsでarmを閉じ、FIREなし | solve同時成立で誤発火 | tie test + closed_by |
| RESOLVE commit | exactly one rumination/counter progression | duplicate/stale preview | multi-view + stale token test |
| snapshot | v8 rowにbound terms/counter idsを保存 | load時rebind drift | save-load-save + future continuation |

