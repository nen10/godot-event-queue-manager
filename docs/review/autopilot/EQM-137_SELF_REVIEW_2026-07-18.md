# EQM-137 Self Review — reaction-condition contract hardening

Date: 2026-07-18
Task: EQM-137 / roadmap Phase 15 / queue Phase 14
Primary classification: runtime integration + trigger/reaction + resilience

## Outcome

`reaction_condition`の誤型がstatusをARMEDへ変えた後にindexでSCRIPT ERRORとなる
false-greenを解消した。authoritative submitは`EQCondition|null`以外を発行前に拒否し、
stable faultと`reservation_rejected` traceを残す。engine/indexの直接callerもbool/-1で
副作用なしに拒否する。

EBS current headではbridge preflight、正しいnormalized-event trigger標準形、GUT script-error guard、
consumer-owned docsを追加した。EBS側変更は同repo規約に従い、このEQM commitには含めない。

## Acceptance review

- [x] wrong type: reservation PENDING、event id -1、effect bindings -1、issued meta未bind。
- [x] engine canonical table、target/wildcard index、sequence、scheduler、expiryは不変。
- [x] DEVはstable fault + trace + halted。SHIPPEDは同じ拒否を記録し、haltせず後続valid reactionが発火。
- [x] direct engine/indexはexplicit false/-1を返し、次のvalid index sequenceは0。
- [x] valid null/EQCondition、arm order、rumination、expiry、snapshot/goldenの既存回帰がPASS。
- [x] EBSの誤った`EQConditionSpec` triggerはbridgeで拒否し、未実装のnamed solve gate主張をconsumer test/docsから除外。
- [x] EBS runnerが実際のGUT 166/166 false-green + SCRIPT ERRORをexit 1へ変換し、修理後166/166 PASS。
- [x] performance suiteは通常回帰から独立したまま双方PASS。

## Changed-file / boundary audit

| area | result |
|---|---|
| `EQError` / ERROR_CONTRACT | append-only `REACTION_CONDITION_TYPE_INVALID`; CONTRACT_VIOLATION / ERROR / editor+game |
| `EQReservationRuntime.submit` | validation直後、actor/effect/meta/status mutation前のpreflight |
| `EQTriggerEngine.arm` | return bool; index成功後だけARMED/canonical append |
| `EQTriggerIndex.add` | wrong typeは-1、sequence/bucket/binding不変 |
| trace | invalid inputだけopen kind `reservation_rejected`; normal trace/goldens不変 |
| snapshot schema | unchanged |
| L0/L1 surface | unchanged; L2 `arm` return only additive |
| consumer boundary | EBS coreへEQM/space type漏出なし。EBS integration/tests/docsだけを変更 |

## API/golden audit

`tests/golden/api_surface.json`は明示更新した。diffは次の2点だけ。

- `EQTriggerEngine.arm`: `void` → `bool`。
- `EQError.REACTION_CONDITION_TYPE_INVALID`追加。

既存method/field削除、L3→L0/L1 leak、snapshot/golden trace更新はない。

## Test summary

| command | result | classification |
|---|---|---|
| `./tools/test.sh` | PASS: 74 files / 1,757 checks / 0 failures (`20260718-223514-52656`); coverage 34 implemented + 1 reserved (EQM-141), 0 violations | passed |
| `./tools/test.sh --performance` | PASS: 4 files / 16 checks / 0 failures (`20260718-223533-53363`) | passed |
| EBS `./tools/test.sh` | PASS: 166/166 / 574 asserts | passed |
| EBS `./tools/test_performance.sh` | PASS: 5/5 / 16 asserts | passed |
| EBS `./tools/package_addon.sh --check` | package manifest/zip generated | passed |

初回sandbox内EQM runはGodot `user://logs`作成失敗後SIGSEGVとなったためsandbox外で再実行。
最初のEBS runは型付きcondition配列のtest typoでSCRIPT ERRORとなり、GUTは166/166と表示したが
新guardがexit 1へ変換した。testを修理して再実行しgreenを確認した。

## Deviation / repair-now audit

| item | classification | resolution |
|---|---|---|
| invalid pre-submit trace | planned refinement | fake `invalid_event_skipped`でなく`reservation_rejected`を採用 |
| API return type | intended additive change | callerがdirect rejectionを判定できるbool; golden diff reviewed |
| EBS current dirty update | user-owned existing work | prepared-plan/validator差分を保持し、対象箇所だけ追記 |

Repair-now: none。trace exact shape、SHIPPED full pipeline、EBS R04 claimの3件は修理・再検証済み。
Follow-up-ready:

- EQM-141: reaction definition solve/invalidationをFIRE occurrenceへ適用する意味論修理。
- consumer finalization: このEQM addon commit hashをEBS `DEPS.md`とdevelopment logへ記録し、
  EBS gateをそのrevisionで再確認する（hash確定後のため本commit直後に実施）。

Proof grade: `contract_tested` + consumer integration proof。statusはconsumer hash記録を残す
`COMPLETE_WITH_BACKLOG`。
