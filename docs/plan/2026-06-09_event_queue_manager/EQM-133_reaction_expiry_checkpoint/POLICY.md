# EQM-133 POLICY — reaction-expiry checkpoint

## Adopted contract

- schema v6の`reaction_expiries`は全live scheduler `expiry` eventとreservation valueを1:1で所有する。
- durationつきarmed rowの`expiry_event_id`は同じvalueを参照し、load後は同じlive reservation instanceを共有する。
- count終了後はarmed rowだけが消え、expiry rowは`RESOLVED`かつremaining count 0として残る。
- scheduler kind／actor／payload、reaction kind／duration、armed membership／status、event-id集合をverify-before-mutateで照合する。
- v1-v5はarmed rowにexpiry linkがある場合だけmigrateする。historical orphan expiryはidentityを推測せずstable rejectionする。
- `resolve_one_scheduled_event()`はscheduler popを最大1件処理し、stable outcomeとevent identityを返す。
- `resolve_next()`はexpiry／invalidation／faultを内部消費する互換挙動を維持する。

## Rejected / deferred

- stale expiryのsilent cancellation。
- current worldや同actorのreactionからhistorical reservationを推測するmigration。
- expiry presentation、ゲーム上の追撃／慈悲意味、typed expiry transaction。

## State / Invariant Table

| state | invariant | proof |
|---|---|---|
| ARMED | armed rowとexpiry rowが同じvalue、scheduler due=`armed_at + duration` | v5 migration + v6 roundtrip |
| COUNT_CLOSED | armed rowなし、expiry row=`RESOLVED`、remaining 0 | exhausted checkpoint test |
| RESTORED | scheduler expiry集合とtable集合が完全一致 | missing／duplicate／orphan rejection |
| EXPIRY_STEP | exact callは1 popだけ処理し後続workを残す | one-event boundary test |
| COMPAT | `resolve_next()`のreturn boundaryと既存trace順は不変 | full suite／golden gate |
