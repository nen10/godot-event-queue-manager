# EQM-136 POLICY — indexed trigger lifecycle and test-lane separation

## Adopted contract

- `_armed`配列がreaction slotの唯一のcanonical truthである。
- `EQTriggerIndex`はarm sequenceをidentityとする非直列化derived cacheであり、target bucket + wildcard candidateだけを返す。
- candidate filter後も`condition.matches(view)`が唯一の最終match判定である。
- arm後の`match_target`変更は同一sequenceを再bucketし、linear scan時代の動的観測を保存する。
- rumination survivorはremove/re-addせず元sequenceを維持する。one-shot、disarm、disarm_for、duration expiryだけがexact slotをindexから除く。
- finite durationのexpiry条件は従来どおり`current_tick - armed_at > duration`。次期限cacheは境界前の全走査を省くだけで意味論を変えない。
- index sequence、bucket、next-expiry cacheはsnapshotへ保存しない。armed tableの配列順からload時に再構築する。
- regression laneはcorrectness / determinism / lifecycle / serializationを所有する。performance laneはwork-count / elapsed / scaleを所有し、通常回帰へ混入しない。

## Rejected / deferred

- indexed/linearのproduction二重実行。
- index不整合時のsilent full-scan fallback。
- post-arm condition mutationを未定義化すること。
- snapshot/APIへのindex設定追加。
- gameplay cap、Amberground balance default、event-line/relation/scheduler/native backend最適化。

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| production linear fallback | do not add | 不整合と性能退行を隠す | — | candidate work-count + parity |
| linear oracle | tests only | indexed結果の意味同一性を証明する | parity propertyが不要になることはない | regression trigger tests |
| null condition | wildcard candidate but never fires | false negativeを作らず既存null挙動を保存 | — | null/nonmatch test |
| index snapshot mirror | do not add | armed tableと二重truthになる | — | save-load-save equality |
| performance in regression | remove | failure分類とwall-clock noiseを分離する | — | suite-boundary runner tests/output |

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| ARMED | canonical rowとindex sequence/bucketが1対1 | duplicate/ghost slot | interleaved arm + counts |
| CONDITION_CHANGED | same sequenceだけがnew bucketへ移る | stale bucket false negative | target→target/wildcard mutation |
| MATCH | `matches()`はtarget bucket + wildcardだけに呼ばれる | full scan regression | counting condition work gate |
| FIRED | occurrence、fire_index、closes_arm、arm orderがlinear oracleと一致 | order/trace drift | parity matrix + existing goldens |
| SURVIVOR | rumination slotは同じsequenceで残る | re-addによる順序後退 | old survivor + later arm test |
| CONSUMED | one-shotはarmed/index双方から消える | repeated fire | repeated matching view |
| EXPIRED | deadline tickでは生存、tick+1で発火前invalidate | off-by-one/stale candidate | boundary + expired order |
| DISARMED | `disarm`はduplicateのfirst slot、`disarm_for`はowner全slotをarm順で除く | wrong slot removal | lifecycle matrix |
| RESTORED | index/cacheはarmed rowsから再構築されsave valueに出ない | schema/continuation drift | save-load-save + continued trace |
| TEST SUITE | regression/performance discovery集合は排他的 | mixed execution/empty green | suite output + zero/unknown fail-closed |

## Public boundaries

- Public method signatures、API layer、snapshot schema、trace record schemaは変更しない。
- `EQCondition.match_target`のsetterは既存property assignmentを保ち、derived indexへ`changed`通知する内部整合点だけを追加する。
- wall-clockはGodot version/build/hostの影響を受けるため、profileにenvironmentとrun idを併記する。
