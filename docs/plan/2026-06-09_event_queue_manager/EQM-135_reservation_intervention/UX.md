# EQM-135 UX — reservation meta intervention

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---:|---:|---:|---|---|
| window介入だけでprepared actionを表す | low | high | low | reject | 解決windowを持たない発行済み予約を対象にできない。 |
| event idで対象予約を指定する | high | low | low | adopt | schedulerとtraceのstable identityをそのまま使える。 |
| meta不足をfaultにする | low | medium | low | reject | 回避は正常なゲーム結果であり異常ではない。 |
| meta不足は予約維持 + `intervention_avoided` | high | low | low | adopt | 結果を観測可能にしつつ対象actionを変えない。 |
| 非対応contextをbest-effortで一部cancelする | low | high | medium | reject | group不変条件を壊し、effect実行有無が不透明になる。 |

## Experience steps

1. consumerは通常のPREPARED予約をsubmitし、返されたevent idを保持する。
2. 介入発生時にevent idとintervenerの発行時meta／event idを渡す。
3. intervener metaが予約meta未満なら、予約は予定どおり残り回避traceだけが増える。
4. 同値以上なら予約は解決前に無効化され、effectは実行されず`closed_by: intervention`が残る。
5. bundle／race／reaction FIREや存在しないidはstable errorとなり、対象状態を変更しない。

ゲーム側の損害、演出、対象選択、intervener meta値付けはconsumer-ownedである。
