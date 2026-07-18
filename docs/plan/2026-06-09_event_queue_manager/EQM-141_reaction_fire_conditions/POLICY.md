# EQM-141 POLICY — reaction FIRE gate

## Adopted decisions

- `EQCondition`はresolved event candidateのmatcher、definitionの`EQConditionSpec`配列は
  match後・FIRE commit前のlevel gate。相互変換しない。
- gate viewはlive objectを含まない`{"trigger": canonical event view, "reaction": reservation view}`。
- solve=AND、invalidation=OR、同時成立はinvalidation-wins。solve=falseはWAITで、arm、status、
  `remaining_ruminations`、declared counterを一切変更しない。
- invalidation成立はarmed reservationそのものをINVALIDATEDへ閉じ、`closed_by`を記録する。
- authored conditionsはarm時に一度だけbindする。reactionのduration/reaction_count sugarはbound
  termから除外するが、そのduration／authored rumination／remaining rumination自体はexact arm
  slotへ固定する。同じreservation objectのduplicate slotでもlifecycle stateを共有しない。
- gate ownershipはreservation objectではなくtrigger-engine arm slot。definition Resourceをarm後に
  編集しても、arm-time authored spec snapshot／bound term／duration／rumination／別slotのgateは
  書き換えない。reservationのstatus/countはduplicate slotが残る間の互換projectionに限る。
- declared COUNTERはarmごとにcounter lineを一つ発行し、accepted FIRE commitごとに-1する。
  counter termをsolve側へ置くとexhaustionまで自力では成立しないためvalidationで拒否し、
  use closureはinvalidation側だけに宣言する。
- FIRE-timeの予期せぬcondition FAULTはruminationを消費せずarmをfail-closedで閉じ、runtime faultと
  `closed_by: condition_fault`を残す。通常の未登録predicate/unknown lineはsubmit/load preflightで防ぐ。
- scheduled FIRE occurrenceへ元definitionのsolve/invalidationを再bindしない。gateはarm slotで既に
  commit済みである。
- cascade budget、serializable cause、actor registration、全FIRE scheduleを先に成立させ、最後に
  engine rumination／declared counter／arm closureをbatch commitする。失敗時はuseを消費しない。
- save schema v8は各`armed_triggers` rowへ`solve`、`inv`、`counter_lines`を必須保存する。
  event-linesはgenerated counter id provenanceも保存し、reserved namespace、exact term shape、
  全gate間unique mapping、active counter value範囲、armed rowのkind/status、非負counter sequenceを
  verify-before-mutateする。
  v1–v7はauthored gateが空のarmだけempty gateとして移行できる。条件付きarmはbind時anchorを
  復元できないためverify-before-mutateでrejectする。

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| mutating `on_event_resolved_occurrences` | compatibility wrapperとして維持 | direct engine consumer | next major API cleanup | legacy engine tests |
| runtime arm gate private table | adopt | engineをcondition-evaluatorへ依存させない | public reaction object redesign時 | lifecycle/save tests |
| scheduled FIRE `_bound_inv`再評価 | remove |別viewでの二重gateになる | immediate | predicate call count |
| v1–v7 gated-arm rebind | do not guess | relative/counter anchor不明 | n/a | historical fail-closed |

## State / Invariant proof

preview tokenはengine private sequenceとreservationを持つ。pure previewは期限切れを非破壊filterし、
compatibility wrapperだけがstandalone expiryを適用する。runtimeは複数viewのaccepted countをslot単位で
計画し、schedule成功後のbatch commitで同じlive tokenを再確認するため、stale preview／schedule failure／
同一reservationのduplicate slotでも二重消費やgate上書きが起きない。同一slotの後続viewがFAULTなら
そのslotの先行accepted viewも破棄し、resilience modeに関係なくpartial FIREを発行しない。runtime gate tableとwatched-line
refcount cacheはarm membershipと同じ寿命で、count close、condition close、duration、actor removal、
save/loadの全経路で同時に追加・削除される。
