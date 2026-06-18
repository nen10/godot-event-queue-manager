# EQM-083 SUB_TASKS

## Complexity

Class: C3 (orchestrator-direct — 最初の UI surface、projection contract を確立)
Reason:
- player-facing runtime timeline HUD + consumer debug overlay。projection-first (injected prediction の描画、UI 側 order 再計算なし)。`ui_metric_id` metadata、stale state、非文字 modality。EQM-090 (editor dock) が同 pattern を踏襲。

Required artifacts: Complexity header / Task Resolution / POLICY (projection contract) / IMPLEMENTATION_PLAN。UX は本 SUB_TASKS の user-goal に畳む。

## User goal

game 開発者が EQManager に HUD を繋ぐと、次 N turn の予測順序が表示され、`queue_changed` で更新され、presentation deferred 中は明示 stale 表示になる。順序/状態は icon/badge (非文字) でも示され (colorblind/SR 安全)、label は localizable。別 opt-in debug overlay で live order と "why next" を開発者が自 game 内で覗ける。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQTimelineHud (Control, ui) | injected prediction の projection | adopt | `set_state(order, stale)`。row ごとに `ui_metric_id`。UI 側 recompute なし。非文字 badge。 |
| stale state 明示 | presentation deferred 中 | adopt | set_state の stale flag → stale badge。silent fallback なし。 |
| 非文字 modality | order/state を icon/badge | adopt | position badge (番号) + stale icon。label は tr()。 |
| EQDebugOverlay (Control, ui) | live order + "why next" | adopt | opt-in。injected order + explanation data (decided_by) を表示。 |
| eq_timeline_hud.tscn | scene | adopt | root に HUD script。 |
| UI 側で order を再計算 | — | reject | projection-first (L4)。injected order を verbatim。 |

## 委譲判断

P0 (最初の UI surface、projection contract を正しく確立し EQM-090 へ波及)。以降の pattern 踏襲タスクは Codex 委譲を検討。

## Scheduled Task Audit

新規 scheduled task なし。次の依存解放は EQM-084 (dogfood)。editor timeline dock は EQM-090 (本 HUD の projection pattern を踏襲)。
