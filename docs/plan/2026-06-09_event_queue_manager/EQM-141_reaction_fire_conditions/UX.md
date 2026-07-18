# EQM-141 UX — event match plus durable reaction gate

## User goal

game側は「どのresolved eventを見るか」を`EQCondition`で宣言し、「現在の空間・状態事実が
発火を許すか」をdefinitionのserializable `EQConditionSpec`で宣言できる。候補eventが一致しても
solveが偽なら準備は残り、後の一致で述語が真になった時だけFIREする。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| normalized tagだけで空間事実を表す | medium | high | low | reject | R04のgame-side named predicate要件を置換する |
| transient custom predicateをmatcherへ置く | low | high | low | reject | save/load後にCallableが消える |
| `EQCondition` matcher + named solve/invalidation | high | low | medium | adopt | 二層の役割と永続化が明確 |
| predicateへtrigger/reaction composite viewを渡す | high | low | medium | adopt | serializableなcauseとowner定義を同時に参照できる |

## Experience steps

1. gameはpredicate名をruntimeへ登録する。
2. reaction definitionへsolve/invalidation specsを設定し、event matcherと一緒にarmする。
3. matcher一致時、predicateは`{trigger, reaction}`のdeep-copy viewを読む。
4. solve=falseならFIREせず同じarmを保持する。
5. invalidation=trueなら`closed_by`を記録してarmを閉じる。
6. solve=trueかつinvalidation=falseなら一回だけcommitし、FIRE occurrenceへcauseを保存する。
7. save/load後も同じbound gateとcounter残量から続行する。

