# EQM-141 Self Review — reaction FIRE conditions

Date: 2026-07-19
Task: EQM-141 / dynamic follow-up / EQM-137 false-green closure
Primary classification: reaction semantics + arm lifecycle + snapshot v8

## Outcome

resolved event候補を選ぶ`EQCondition`と、候補match後にFIRE可否を決めるdefinition
`solve_conditions`／`invalidation_conditions`を二層として接続した。候補previewは非mutationで、
solve=falseは同じexact slotをARMEDのまま保持する。invalidation成立またはcondition faultだけが
FIRE前にslotを閉じ、RESOLVEだけが独立FIRE occurrenceをscheduleした後にrumination／declared
counter／membershipをbatch commitする。

R04 consumer proofは「現在域内」というlevel factや「侵入後の次event」ではなく、movement
effect commitがoutside→insideのentry edgeを同じresolved event viewへ投影し、その同じsweepで
named solveが成立する形に戻した。outside→outsideとinside→insideはWAITし、FIRE effect handlerと
effect recordが一度だけ実行されるところまで観測する。

## Acceptance review

- [x] `EQCondition|null`だけがtrigger candidate matcherで、`EQConditionSpec`と相互変換しない。
- [x] previewはstatus／remaining use／counter／membershipを変更せず、stale token再利用を拒否する。
- [x] gate viewはdeep-copyされた`{trigger, reaction}`で、named solveのfalse→trueを同じarmで継続する。
- [x] invalidation-wins、condition fault fail-closed、cascade/context/actor/schedule failureのuse非消費を固定した。
- [x] 同一slotのmulti-view計画はatomicで、後続FAULT時に先行accepted FIREもDEV／SHIPPED共に破棄する。
- [x] authored terms、relative anchor、generated COUNTERをarm時に一度bindし、scheduled FIREでは再評価しない。
- [x] COUNTERはinvalidation-onlyで、solve側宣言をstable validation errorとして拒否する。
- [x] exact slotごとにduration、authored rumination、remaining ruminationを固定し、duplicate slotで共有しない。
- [x] schema v8がbound gate、slot lifecycle、counter provenanceをexactに保存し、load前にshape／range／identityを検証する。
- [x] condition/count/fault後もfinite expiryを保持し、save/load後に`already_closed`で解決する。
- [x] EBS bridgeのone-shot／compiled／Action build plan発行APIがmatcher、solve、invalidationを別引数でdeep-copyする。
- [x] regressionとperformanceのdiscoveryを分離したまま、両laneとEBS consumer/package gateを実行した。

## State / atomicity audit

| state | owner | mutation point | invariant / proof |
|---|---|---|---|
| candidate membership | `EQTriggerEngine` index | arm/disarm only | previewはexpiredを非破壊filterし、commit tokenはslot revisionを検証 |
| FIRE gate | runtime exact slot | arm bind / slot close | definition後編集やduplicate reservation identityから独立 |
| duration/use count | engine exact slot | arm / accepted batch commit | post-arm duration/rumination編集を無視し、slot別FIRE indexを継続 |
| declared COUNTER | generated event line | arm bind / accepted batch commit | reserved namespace + provenance + 1..start active range + cross-gate unique |
| scheduled FIRE | fresh reservation | 全preflight後にschedule | gateを再bind／再評価せず、causeをversioned contextで保持 |
| closure cleanup | runtime slot id | condition/count/fault/duration/departure | gate、watched refcount、engine membershipを同じslotで除去 |
| retained expiry | runtime event id + slot snapshot | arm / slot state commit / expiry | early closure後もstatus/count/authored termsを保存し`already_closed`へ進む |
| snapshot apply | save adapter/runtime | verify成功後のみ | malformed kind/status/spec/counter/identityはactor/scheduler mutation前に拒否 |

`EQTriggerEngine`のcommit/invalidate/disarmはstandalone surfaceである。
`EQReservationRuntime.engine`として公開されるinstanceはconsumerに対してinspection-onlyと文書化し、
runtime gate／counter／watch／expiryを迂回する直接mutationを正規経路にしない。

## Snapshot / compatibility audit

- current bundle schemaは8。各armed rowの`solve`／`inv`／`counter_lines`と、event-linesの
  `counter_ids`／非負`counter_seq`をverify-before-mutateする。
- authored specはexact keyとscalar type、enum範囲、type固有制約を検査する。active counterは
  `1..counter_start`だけを許し、consumer line alias、provenance欠落、cross-gate id再利用を拒否する。
- armed rowはstatus `ARMED`、definition kind `REACTION_PREPARATION`をdurationに関係なく要求する。
- v1–v7はempty-gate armだけを移行する。historical conditioned armはbind anchor／counter identityを
  推測せず`eqm.reaction.fire_gate_state_invalid`で拒否する。
- callerがarm後にconditions／duration／ruminationを編集しても、writerはarm-time slot snapshotを
  出力し、save-load-saveとfuture FIRE indexを一致させる。

## Test summary

| command | result | classification |
|---|---|---|
| `./tools/test.sh` | PASS: 76 files / 2,066 checks / 0 failures (`20260719-014725-74509`); API/coverage/golden/package gates PASS | regression |
| `./tools/test.sh --update-golden focus_cost_counter_stop` | PASS: explicit rebaseline run (`20260719-012638-40405`) | golden policy proof |
| `./tools/test.sh --performance` | PASS: 5 files / 49 checks / 0 failures (`20260719-014410-69780`) | performance-only |
| EBS `./tools/test.sh` | PASS: 169 tests / 623 asserts / no script-load error | consumer regression |
| EBS `./tools/test_performance.sh` | PASS: 5 tests / 16 asserts | consumer performance-only |
| EBS `./tools/package_addon.sh --check` | PASS: manifest and zip generated | package |

Performance values remain advisory and operation-local. This task added no semantic fixture under the
performance directory; it only re-ran the independent existing lane. Latest observed EQM values were
event-line selection 188.69x, effective-rate lookup 18.69x, relation queries 514.12x／648.65x／
1,007.21x, and trigger candidate merge 4.54x／9.95x. Latest EBS values were formula 2.27x,
bridge 1.34x, validator 3.81x, Action plan 1.38x with 6 usec preparation and break-even 2,
and compiled issue 1.13x.

## Golden / API audit

- `tests/golden/api_surface.json` was explicitly updated for the new preview/commit methods and append-only
  stable errors. Layer/untagged/L3 leak gate passes.
- `focus_cost_counter_stop.trace.jsonl` was explicitly rebaselined. The old trace scheduled a fifth FIRE and
  invalidated that pending occurrence; the corrected FIRE gate observes `focus_exhausted` before scheduling,
  so the fifth `reaction_fired` disappears and one direct condition closure records `trigger_event_id`.
  This is the intended semantic change, not incidental ordering churn.
- Other deterministic trace fixtures remain at their asserted contract.

## Deviation / repair-now audit

| finding | classification | resolution |
|---|---|---|
| EBS passed GUT while wrong `EQConditionSpec` trigger caused `SCRIPT ERROR` after status became ARMED | original false green | EBS type boundary + runner script/load guard + actual FIRE/effect acceptance |
| first review found precondition-after-commit, reservation-keyed gates, counter alias/provenance, mutable-definition save drift, mutating preview, solve COUNTER deadlock | repair-now P1 | schedule-before-batch-commit、slot-keyed gate、reserved provenance、arm snapshot、pure preview、validation rejection |
| first review found O(arms) watched derivation and DEV continuation after fault | repair-now P2 | watched-line refcount cache + halt-aware sweep |
| second review reproduced duplicate-slot shared remaining/status, unlimited-arm schema gap, duration/rumination drift, negative counter sequence | repair-now P1 | exact slot lifecycle + strict schema/tamper regressions |
| schema audit found invalid authored values、active counter range、cross-gate alias、missing predicate gaps | repair-now P2 | exact scalar/enum/type/range/registration verification |
| final schema audit found negative/overflowing remaining lifecycle and bound-term scalar/identity coercion | repair-now P1/P2 | exact slot lifecycle relationships + exact bound-term type/identity verification and tamper regressions |
| multi-view later FAULT differed by resilience mode | repair-now P2 | same-slot earlier FIRE discard in DEV/SHIPPED regression |
| runtime-owned engine could be mutated through standalone methods | contract boundary | inspection-only ownership documented; runtime regression uses pipeline path |
| first EBS test moved actor before a later event and observed only trace | proof false green | same movement effect emits entry edge; inside motion WAIT; handler count/context/effect record asserted |

Final independent review found no remaining blocker after these repairs.

Repair-now: none.
Follow-up-ready: none created; further game-specific damage/delay meaning remains consumer-owned.
Proof grade: `contract_tested` + consumer acceptance + schema tamper + independent lane separation.
