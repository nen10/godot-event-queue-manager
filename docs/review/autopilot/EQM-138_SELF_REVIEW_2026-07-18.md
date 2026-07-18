# EQM-138 Self Review — stable trigger candidate merge

Date: 2026-07-18
Task: EQM-138 / roadmap Phase 15 / queue Phase 14
Primary classification: trigger determinism + runtime performance

## Outcome

`EQTriggerIndex.candidates()`のtarget + wildcard concat後full sortを除去した。各derived
bucketをimmutable arm sequence順に維持し、mixed queryはO(t+w)のtwo-way merge、
single bucketはfresh outer Arrayで返す。通常armはO(1) append、古いslotをcondition
mutationでpopulated bucketへ移す時だけordered insertionを行う。

Public API、resource/snapshot schema、trace/golden、canonical armed tableは変更していない。

## Acceptance review

- [x] target-only / wildcard-only / mixed候補はexact global arm order。
- [x] shared conditionのseq 0/2をseq 1入りtargetへ移してもoccurrence
  `[actor_id, fire_index, closes_arm]`が完全一致。
- [x] older specific slotをpopulated wildcardへ移しても完全一致。
- [x] single-bucket fast pathはinternal Array aliasを返さない。
- [x] remove/disarm/expiry/rumination/clear/save continuationの既存回帰がPASS。
- [x] production candidate assemblyにfull candidate sortは残らない。
- [x] regression/performance discovery分離を維持し、双方PASS。

## Algorithm / state audit

| area | result |
|---|---|
| canonical state | `EQTriggerEngine._armed`のまま。indexは非serialize派生状態 |
| bucket invariant | target/wildcardとも`seq` strictly ascending |
| add | fresh sequenceなので末尾fast append |
| retarget | lower-bound insertion。reservation/condition/statusは変更しない |
| remove | 1 slot eraseで残りのsorted orderを保存 |
| query | empty/singleはduplicate、mixedはpre-sized linear merge |
| complexity | candidate assembly O(c log c) → O(c), c=t+w |

## Performance evidence

Fixtureはproduction engine 1,000 arms、40 targets、非matching tag。hard gateは候補数、
matcher call数、fired/retained数、legacyとのexact sequence parity。elapsedは同一processの
test-only legacy production copyとのadvisory A/Bであり、portable SLAではない。

| scenario | candidates | observed A/B range | assembly-time reduction |
|---|---:|---:|---:|
| sparse (wildcard every 20) | 75 | 4.43–4.65x | 77.4–78.5% |
| wildcard-heavy (wildcard every 4) | 275 | 9.93–10.24x | 89.9–90.2% |

各値は20 warmups後、500 assemblies × 6 samples（旧→新/新→旧を3回ずつ）のcentral-pair
average。3 complete runsのraw sample/medianは`docs/design/RUNTIME_PERFORMANCE_PROFILE.md`。
これはcandidate-array assemblyだけの改善で、sweep全体・effect handler・frame timeの
倍率ではない。

## Test summary

| command | result | classification |
|---|---|---|
| `./tools/test.sh` | PASS: 74 files / 1,761 checks / 0 failures (`20260718-224934-81074`); API/coverage gates PASS | passed |
| `./tools/test.sh --performance` | PASS: 4 files / 22 checks / 0 failures (`20260718-224906-80604`) | passed |
| same performance command | PASS (`20260718-224950-81434`) | repeated evidence |
| same performance command | PASS (`20260718-225017-81801`) | repeated evidence |

## Deviation / repair-now audit

| item | classification | resolution |
|---|---|---|
| first regression parse failure | test edit placement | moved existing wildcard subcase back to its original function; rerun PASS |
| initial A/B used synthetic legacy entries/fixed order | repair-now measurement validity | discarded all initial ratios; exact removed-production baseline + alternating orderへ修理し3 runs再計測 |
| third heavy sample variance | advisory noise | raw 6 samplesを公開し、3-run rangeで報告。hard gateにelapsed不使用 |

Repair-now: none.
Follow-up-ready: none from this task; next dependency task is EQM-139 relation adjacency.
Proof grade: `contract_tested` + deterministic work gate + environment-labelled advisory A/B.
