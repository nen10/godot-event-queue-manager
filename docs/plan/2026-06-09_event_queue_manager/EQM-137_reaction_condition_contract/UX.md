# EQM-137 UX — explicit reaction-condition rejection

## User goal

adapter/consumer開発者が誤ったcondition Resourceを渡したとき、成功に見えるghost armを
作らず、安定codeと状態非変更で即座に原因を判別できる。正しい`EQCondition`またはnullを
渡す既存callerには追加操作を要求しない。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. duck typing (`match_target`/`matches`) | low | high | low | reject | typoや別Resourceをaccepted contractにしてしまう |
| B. `EQCondition | null`を明示契約にする | high | low | low | adopt | trigger matcherとpending condition specの役割が一意になる |
| C. wrong typeを空wildcardとして扱う | low | critical | low | reject | 意図しない全event triggerまたはinert ghostを作る |
| D. wrong typeをstructured rejectionとして返す | high | low | medium | adopt | dev/shipped双方で診断可能、mutation前に閉じられる |

## Experience steps

1. callerはreaction reservationと`EQCondition`（またはnull）をsubmitする。
2. 正常入力は従来どおりarmされる。
3. 別型を渡した場合、submitは`-1`を返し、reservationはPENDINGのまま、engineにも
   schedulerにも登録されない。
4. runtime faultと`reservation_rejected` traceがstable codeを示す。devはhalt、shippedは
   後続の正常入力を処理できる。

## Maintained / removed paths

- 維持: `EQCondition`のkind/source/target/tag/custom predicate matching、nullのinert arm。
- 廃止: `EQConditionSpec`など任意Resourceをreaction triggerとして黙って受ける経路。
- 保留: serializable named trigger predicate。現standard formはnormalized event tagを
  `EQCondition`で選ぶ。definition solve/invalidationのFIRE適用は既存R04契約の独立修理。
