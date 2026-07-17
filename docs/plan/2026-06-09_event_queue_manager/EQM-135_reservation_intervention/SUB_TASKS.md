# EQM-135 SUB_TASKS — reservation meta intervention

## Complexity

Class: C3

Reason:
- scheduler、reservation instance、snapshot、trace、公開L2 APIを同時に変更する。
- window介入を再利用せず、対応する単独予約と非対応contextを明示的に分ける必要がある。

Required artifacts:
- Task Resolution / Scheduled Task Audit
- UX / POLICY / IMPLEMENTATION_PLAN
- state/invariant table、dependency/test matrix、self-review

## Task Resolution

| candidate | decision | reason |
|---|---|---|
| `intervene_close`へ予約idを混在させる | reject | window lifecycleとscheduled reservation lifecycleの対象identityが異なる。 |
| definitionの現在metaを比較時に直読する | reject | 発行後のauthoring値変更で既存予約の意味が変わる。 |
| submit受理時のmetaをinstanceへ固定する | adopt | 発行時samplingを保存し、将来のconsumer補正も同じ搭載値へ集約できる。 |
| bundle／race／reaction FIREにもv1を一般化する | reject | group bookkeepingと発火causeの意味を暗黙に変更する。 |
| PREPARED singletonだけをfail-closed APIで閉じる | adopt | Amberground需要を満たしつつ、既存group semanticsを保存する。 |

## Scheduled Task Audit

本taskはAmberground interception trancheの確定済み需要を実装するdynamic follow-upである。bundle/race/reaction FIREへの一般化は実需要と意味論が確定するまで起票しない。presentationとinterception damageはconsumer-ownedでありEQM taskへ展開しない。
