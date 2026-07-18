# EQM-136 IMPLEMENTATION PLAN — production trigger index and performance lane

## Scope

Production trigger matchingをtarget indexへ透明に接続し、期限境界以外のexpiry full scanも避ける。同時に、速度・規模測定を通常回帰から排他的なperformance suiteへ分離する。caller API、trace、snapshot schema、gameplay semanticsは変更しない。

## Target files

- `addons/event_queue_manager/resources/eq_condition.gd`
- `addons/event_queue_manager/runtime/eq_trigger_engine.gd`
- `addons/event_queue_manager/runtime/eq_trigger_index.gd`
- `test_project/tests/run_all.gd`
- `test_project/tests/{core,trigger,performance,support}/`
- `tools/test.sh`
- `docs/devflow/{PROJECT_PROFILE,TEST}.md`
- `docs/design/{RUNTIME_PERFORMANCE_PROFILE,STATE_RELATION_WORK_SCALE}.md`
- roadmap / queue / self-review

## Implementation steps

1. test runnerへ`regression|performance`の明示suiteを追加し、unknown/zero-fileをfail-closedする。
2. `tools/test.sh`の通常modeをregression限定、`--performance`をperformance限定にし、performanceではPython/UI/goldenを実行しない。
3. heap parity、trigger index parity、state/relation work-scaleのcorrectnessとtimingを責務別fileへ分割する。
4. `EQTriggerIndex`へsequence exact removalとcondition target再bucketを内部追加する。
5. `EQCondition.match_target`変更で`changed`をemitし、indexが同sequenceを追随する。
6. `EQTriggerEngine`へderived index、sequence lookup、next finite-expiry cacheを統合する。
7. target/wildcard順序、duplicate disarm、rumination order、expiry境界、target mutation、save/load continuationを通常回帰で証明する。
8. actual engineのtotal armed / candidate / matches call / fired / elapsedをperformance laneで測定しprofileへ記録する。
9. API/schema/golden無変更を標準gateで確認し、self-reviewとqueue proofを閉じる。

## Out of scope

- event-line watched-set cache、relation adjacency、scheduler live-peek/default backend、trace retention。
- native/GDExtension。
- consumer gameplay limitやAmberground側benchmarkとの比較。

## Fallback handling

linear implementationをproduction fallbackとして残さない。test oracleはtest file内だけに置く。index/cacheからcanonical stateを復元する経路は作らない。

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| EQM-102 index parity | filterがfull matchを置換しfalse result | target/wildcard/tag/source/custom matrix |
| EQM-132/133 occurrence semantics | fire_index/cause/expiry ownership drift | reaction-fire-context + stale-expiry continuation |
| EQM-134 work scale | latency promise/game capへの誤用 | separate correctness fixture/profile docs |
| mutable condition Resource | stale target bucket | changed-signal retarget regression |
| duplicate arm / rumination | wrong slot removal/order drift | sequence identity lifecycle tests |
| expiry cache | deadline off-by-one/expired order drift | tick boundary + linear parity |
| snapshot | derived stateの二重serialize | save-load-save exact equality; schema v7 |
| suite separation | performance混入/empty green | printed suite/file boundary + invalid mode failure |
| performance | wall-clock noise | deterministic matches-call hard gate + environment-labelled elapsed |
| public surface | callerへindex tax/L3 leak | API surface golden unchanged |

## Test path

- `./tools/test.sh` — regression only。
- `./tools/test.sh --performance` — performance only。
- `git diff --check`。

## Completion checklist

- [x] regression discoveryに`tests/performance`が含まれない。
- [x] performance discoveryにregression/UI/Python checksが含まれない。
- [x] production engineがcandidate subsetだけをfull-matchする。
- [x] order/lifecycle/condition mutation/save continuationが不変。
- [x] performance profileがwork reductionとelapsedを記録する。
- [x] API/schema/golden diffなし。
- [x] self-reviewにrepair-nowなし。
