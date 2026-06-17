# EQM-061 POLICY

## 採用判断

- **EQTriggerEngine (L2)**: armed reaction を保持し sweep point で照合・発火する。
  - `arm(reservation, condition, current_tick)`: REACTION_PREPARATION reservation を condition と pair し ARMED 化、armed_at=current_tick を記録。
  - `on_event_resolved(view, current_tick) -> Array`: (1) **expire**: `duration != -1` かつ `current_tick - armed_at > duration` の armed を発火前に drop (status INVALIDATED)。(2) **fire**: 残存 armed のうち `condition.matches(view)` を満たすものを発火 (status RESOLVED、fired に追加、**one-shot で _armed から除去**)。fired を返す。
  - 発火は **sweep point** (各 event 解決直後) でのみ評価 (SEMANTICS §6; 解決中に interleave しない)。
- **owner/source 区別**: engine は owner=reservation.actor_id を保持。EQCondition の match_target=owner / match_source / custom_predicate で「敵 source・owner target」を表現。自傷 (source==owner) は predicate で除外可能。
- **発火 = one-shot** (本 task)。rumination による再武装 (N 回) と無限連鎖 cycle guard は EQM-062。
- condition は arm 時に渡す (EQActionDefinition を変更しない)。

## 不採用判断

- rumination 再武装 / cycle guard の本 task 実装 (EQM-062)。
- 解決中の trigger interleave (sweep point のみ、§6)。
- fired reaction の実 scheduling を engine が直接行う (consumer/runtime の責務; engine は detection)。

## Invariants

- expire は fire より先 (duration 切れは発火しない)。
- 発火は決定的: 同 armed 集合・同 view・同 tick で同じ fired。
- one-shot: 発火/失効した armed は _armed から除去 (二重発火なし)。
- duration=-1 (∞) は時間失効しない。
- sweep point 外では発火しない。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| armed expire | duration 経過で発火前 drop | 期限切れ発火 | arm@0 dur5; event@8 → 発火せず (expired) |
| fire on match | condition 一致で発火、one-shot | 二重発火 / 不一致発火 | damage match→fired 1件、再 resolve→0 |
| owner/source | 敵攻撃に反応、自傷に非反応 | 誤反応 | target=owner で発火、target≠owner / source==owner で非発火 |
| sweep timing | 解決直後のみ | interleave | on_event_resolved 経由のみ発火 |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| duration 切れ | drop (INVALIDATED) | 反応窓終了 | — | expired 非発火 |
| 不一致 event | armed 維持 | 他 event を待つ | — | 非 damage で armed 維持 |
| condition null | 発火しない (安全側) | 無条件発火を避ける | — | (defensive) |
