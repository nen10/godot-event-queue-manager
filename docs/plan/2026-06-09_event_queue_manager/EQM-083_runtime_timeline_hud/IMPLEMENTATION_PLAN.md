# EQM-083 IMPLEMENTATION_PLAN

## Scope

runtime timeline HUD (projection-first) + opt-in debug overlay を実装。editor dock は EQM-090。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/ui/eq_timeline_hud.gd` — `EQTimelineHud` (Control, ui)。
- `addons/event_queue_manager/runtime/ui/eq_timeline_hud.tscn` — scene。
- `addons/event_queue_manager/runtime/ui/eq_debug_overlay.gd` — `EQDebugOverlay` (Control, ui)。
- `tools/check_api_surface.py` — LAYER_MAP に EQTimelineHud/EQDebugOverlay = `ui`; LAYERS に "ui" 追加。
- `docs/design/API_SURFACE.md` — ui layer 行。
- `tests/golden/api_surface.json` — `--update`。
- `test_project/tests/ui_headless/test_eq_timeline_hud.gd` (new dir) — projection integrity / stale / empty / ui_metric_id / no-recompute / debug overlay。

## 実装 steps

1. EQTimelineHud: set_state(order, stale)、rows()/model、row Control + position badge + stale indicator + ui_metric_id meta。bind_manager(manager) で queue_changed → refresh hook (consumer が prediction 供給)。
2. EQDebugOverlay: set_state(order, explanations)、live order + why-next data。
3. .tscn。
4. LAYER_MAP + API_SURFACE (ui layer)。
5. headless test (Control を tree なしで instantiate、model/meta 検査)。
6. `python3 tools/check_api_surface.py --update`。
7. `./tools/test.sh` PASS。

## Test path / gate

- §4 UI (timeline): L4 projection integrity (表示順 == injected) + state matrix (stale/empty) + ui_metric_id metadata。screenshot 非依存。
- 期待: 既存 489 + 新 checks、api-surface ok、exit 0。

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| EQPrediction (EQM-033) | UI が再計算 | HUD は inject のみ、scheduler 非参照 |
| UI_TESTABILITY (projection-first) | screenshot 依存 | model/meta の headless 検査 |
| presentation deferred (EQM-081) | stale 非表示 | stale flag → badge |
| API surface gate | 無断変更 / ui layer 未登録 | 明示 --update、ui layer |

## Completion checklist

- [ ] HUD が injected prediction を verbatim 描画 (no recompute)。
- [ ] stale/empty が明示 state。
- [ ] row/stale に ui_metric_id metadata。
- [ ] 非文字 modality (badge/icon)、localizable label。
- [ ] EQDebugOverlay が live order + why-next を表示。
- [ ] ui layer、golden 明示更新、`./tools/test.sh` PASS。
