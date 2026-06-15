# EQM-051 POLICY

## 採用判断

- **EQReservationRuntime (L2)**: EQRuntime を wrap し、reservation を kind 別に schedule/resolve する。`_by_event: event_id -> EQReservation`、`_armed: Array` (reaction prep)。
- **submit(res) -> int** (kind 別 scheduling):
  - IMMEDIATE: `current_tick + 0`。PREPARED: `current_tick + delay`。READY: `current_tick + delay`。OPERATION: `current_tick + delay`。
  - WAIT: 新規 READY reservation (delay = wait の delay) を作り submit (= ready 予約を schedule)。wait 自体は RESOLVED。
  - REACTION_PREPARATION: schedule せず ARMED にして `_armed` へ (発火は EQM-061)。
- **resolve_next() -> EQReservation**: `runtime.advance()` で event を pop → `_by_event` で reservation を引き当て RESOLVED 化。OPERATION なら `target_id` に `operation_target_tag` の REACTION_PREPARATION reservation を arm (= operation が target reservation を起こす)。
- **EQReservation.target_id** を追加 (operation の対象)。to_dict/from_dict に含める。
- 解決 event は EQRuntime.advance 経由で **canonical trace に記録**される (kind=&"reservation")。
- condition 評価・trigger 発火は EQM-061 (本 task は scheduling/resolution の骨格)。

## 不採用判断

- condition オブジェクト評価 (EQM-060)。trigger 発火 (EQM-061)。rumination cycle guard (EQM-062)。
- reservation が runtime internal を直接操作 (runtime primitives 経由)。

## Invariants

- submit した reservation は kind 通りの due_tick に載る (immediate=現在、prepared=現在+delay)。
- resolve_next は scheduler の決定的順序で 1 件解決。
- operation 解決後、target_id に対応 tag の reservation が存在する。
- reaction-prep は schedule されず ARMED として照会可能。
- 解決は live state を破壊しない (EQRuntime の整合に従う)。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| submit due_tick | immediate=0, prepared=delay | 誤配置 | scheduled due_tick assert |
| WAIT | ready 予約が生成・schedule | ready 欠落 | submit(WAIT) 後 READY が pending |
| OPERATION resolve | target に tag 付き reservation | 対象予約欠落 | resolve 後 armed_for(target) に tag |
| reaction-prep | ARMED, not scheduled | 誤 schedule | submit 後 scheduler 不変 + armed |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| 未登録 actor へ submit | runtime.schedule が fault (mode 準拠) | RUNTIME_RESILIENCE | — | (継承機構) |
| non-reservation event を resolve_next | null 返し (無視) | 混在許容 | — | _by_event 無しは null |
| operation の target 未指定 | 定義 validation で operation_needs_target | 対象不明 | — | (EQM-050 で担保) |
