# EQM-133 SUB_TASKS — reaction-expiry checkpoint

## Complexity

Class: C3

Reason:
- scheduler、armed trigger、save schema、resolution APIにまたがる公開L2 repairである。
- historical schemaで復元可能な状態と情報消失状態を明示的に分ける必要がある。

Required artifacts:
- Task Resolution / Scheduled Task Audit
- UX / POLICY / IMPLEMENTATION_PLAN
- state/invariant table、dependency/test matrix、self-review

## Task Resolution

| candidate | decision | reason |
|---|---|---|
| schema v5のままarmed rowへclosed expiryを残す | reject | armed membershipを偽装し、発火可能性とserialization所有を混同する。 |
| expiry eventをcount終了時にcancelする | reject | SEM §6.3の`already_closed`観測を変更する。 |
| schema v6独立table + strict verification | adopt | event identityを保存し、複雑tableの誤結合をload前に拒否できる。 |
| `resolve_next()`の戻り意味を変更する | reject |既存consumerのreservation boundaryを壊す。 |
| additive exact-one-event API | adopt | private stateを公開せずinterleaving可能にする。 |

## Scheduled Task Audit

本taskはAmberground checkpoint実装を止める既知seamのrepairであり、追加のgame意味判断を含まない。presentation、typed expiry、reaction-chain fuelは非blocking follow-upのまま維持し、新規scheduled taskへは展開しない。
