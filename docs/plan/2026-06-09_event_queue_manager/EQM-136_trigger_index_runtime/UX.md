# EQM-136 UX — transparent reaction speedup and explicit performance runs

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---:|---:|---:|---|---|
| consumerがindexを作成・同期する | low | high | medium | reject | 利用側APIにperformance taxと同期責任が漏れる。 |
| engineが自動で候補を絞る | high | medium | medium | adopt | authoring/実行手順を変えずに改善できる。 |
| regression実行時にperformanceも暗黙実行する | low | high | low | reject | failure分類と実行時間が混ざる。 |
| `./tools/test.sh --performance`を明示実行する | high | low | low | adopt | lane境界と結果がcommand上で明確になる。 |
| wall-clock passだけを速度の証拠にする | medium | high | low | reject | machine varianceで再現性が弱い。 |
| candidate/matches work-countとelapsedを併記する | high | low | medium | adopt | algorithmic改善と実時間を分けて読める。 |

## User goal

Ambergroundを含むconsumerはreactionの作り方やsave/APIを変更せず、armed reactionが増えたときのevent sweep costを抑えられる。EQM developerは通常回帰と速度測定を混ぜずに、それぞれの責務を明示commandで検証できる。

## Experience steps

1. consumerは従来どおりcondition付きreactionをarmする。
2. event resolution時、engineがevent target bucketとwildcard bucketだけをarm sequence順で選ぶ。
3. full conditionは候補にだけ評価され、fire order、rumination、expiry、traceは従来と同じになる。
4. arm後にcondition targetを変更した場合も、同じslot sequenceのまま自動的に再bucketされる。
5. saveは従来のarmed tableだけを保存し、loadがその順序からindexを再構築する。
6. developerは`./tools/test.sh`でcorrectness回帰だけを、`./tools/test.sh --performance`で速度分類だけを実行する。

## Adopted / retained

- public `EQTriggerEngine.arm` / resolve / disarm API。
- exact arm-order occurrence、rumination counter、count-closed stale expiry、snapshot schema v7。
- normal regressionのAPI/contract/UI/package gates。

## Removed / deferred

- performance directoryの通常runner自動収集を廃止する。
- standalone indexだけの候補縮約をproduction speed proofとして扱う経路を廃止する。
- event-line/relation/scheduler改善は本taskから保留する。
