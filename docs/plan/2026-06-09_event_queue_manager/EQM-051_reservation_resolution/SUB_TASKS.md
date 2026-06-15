# EQM-051 SUB_TASKS

## Complexity

Class: C3
Reason:
- L2 runtime: reservation を scheduler に載せ kind 別に解決する pipeline。EQM-052 (AP-ready)/060+ (trigger) が乗る。
- EQReservation に `target_id` を追加 (operation の対象) → 小さな L2 surface 変更。

Required artifacts: Complexity header / Task Resolution / UX (最小) / POLICY / IMPLEMENTATION_PLAN。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQReservationRuntime | submit/resolve_next で kind 別 scheduling | adopt | EQRuntime を wrap。`_by_event` で event→reservation 対応。 |
| immediate=delay0 / prepared=delay | 基本解決 | adopt | submit が current_tick+delay へ schedule。 |
| wait → ready 予約を schedule | turn-flow | adopt | submit(WAIT) が READY reservation を作り schedule。 |
| operation → target reservation を起こす | 対象予約 | adopt | resolve(OPERATION) が target_id に operation_target_tag の reservation を arm。 |
| reaction-prep = arm (no schedule) | 反応武装 | adopt(最小) | trigger 発火は EQM-061。ここは ARMED 化 + 照会。 |
| EQReservation.target_id 追加 | operation の対象保持 | adopt | to_dict/from_dict + golden 更新。 |
| trigger 発火/condition 評価 | — | defer→EQM-061 | 本 task は scheduling/resolution の骨格。 |

## Scheduled Task Audit

新規 scheduled task なし。次の依存解放は EQM-052 (AP/ready model)。trigger engine は EQM-061、rumination cycle guard は EQM-062。
