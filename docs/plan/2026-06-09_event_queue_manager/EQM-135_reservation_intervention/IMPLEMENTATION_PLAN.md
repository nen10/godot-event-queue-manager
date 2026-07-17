# EQM-135 IMPLEMENTATION_PLAN — reservation meta intervention

## Scope

Amberground interception trancheに必要な、発行済みPREPARED singletonをmeta比較で解決前に無効化するadditive L2 primitiveを追加する。window close、tick freeze、group resolutionの既存意味は変更しない。

## Target files

- `addons/event_queue_manager/runtime/eq_reservation.gd`
- `addons/event_queue_manager/runtime/eq_reservation_runtime.gd`
- `addons/event_queue_manager/runtime/eq_error.gd`
- `test_project/tests/transaction/test_eq_reservation_intervention.gd`
- semantics/API/error/coverage/test docs

## Steps

1. submit受理時のmetaをreservation instanceへ一度だけ搭載し、serializationへ追加する。
2. event idから対象を検証する`intervene_reservation`を追加し、v1非対応contextをstable rejectionする。
3. meta不足は対象不変のavoid trace、同値以上はeffect未実行のatomic cleanup + invalidation traceにする。
4. success/equal/avoid/unknown/non-PREPARED/bundle/race/reaction FIRE、snapshot消失、trace順をtestする。
5. SEM／coverage／API／error／test indexを同期し、API goldenを明示更新する。
6. full suiteとself-reviewを完了する。

## Dependency / Test Matrix

| area | risk | proof |
|---|---|---|
| issuance sampling | definition mutationで既存eventのmetaが変わる | submit後mutation + save roundtrip |
| cancellation | schedulerだけ消えてruntime tableに残る | pending + scheduler size + save_state assertions |
| effect isolation | cancel後にeffectが実行される | handler count + later resolve |
| group safety | bundle/race/FIRE帳簿を部分破壊する | rejection matrix + unchanged pending |
| trace | 成否が曖昧／meta説明不足 | exact ordered records and fields |
| compatibility | L0/L1 leak、既存golden drift | API gate + full suite |
