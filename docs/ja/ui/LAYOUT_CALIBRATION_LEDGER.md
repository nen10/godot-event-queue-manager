# Layout Calibration Ledger

原文: `docs/ui/LAYOUT_CALIBRATION_LEDGER.md`

各 tweak-and-bake iteration を記録します (UI_LAYOUT_CALIBRATION_POLICY.md §5)。calibration tab (`addons/event_queue_manager/editor/testing/eq_calibration_tab.gd`) は debug-only で、`EQ_EDITOR_CALIBRATION=1` のときだけ visible です。user が `ui_metric_id` ごとに layout params を編集し、"Copy Layout Feedback" が schema-valid JSON (`eq_layout_feedback` v1) を出力します。agent はそれを named constants/theme に bake し、`EDITOR_UI_CONTRACT.md` thresholds を更新し、iteration をここへ追記します。

## Bake procedure (summary)

1. feedback JSON を `docs/ui/calibration_inbox/<date>_<surface>.json` に保存する。
2. `edited` を named constants / theme / `custom_minimum_size` として適用する (magic numbers は使わない)。
3. value が metric threshold と conflict する場合は、`EDITOR_UI_CONTRACT.md` §7 を更新し、理由をそこに記録する。
4. old threshold を hard-code している test があれば、contract を参照するよう更新する。削除には self-review reason が必要 (PROJECT_PROFILE test principles)。
5. 下に iteration entry を追記する。
6. `./tools/test.sh` を pass させる。

## Cold-control rule

ある surface の calibrated iteration で **3 回連続 untouched** の control は **cold** と分類し、UX re-evaluation に queue します (simplify/icon-ify、必要性の再検討、または measure の粗粒度化)。cold ≠ delete です。判断は follow-up task の UX candidate matrix で行います。

## Feedback schema (reference)

```json
{
  "kind": "eq_layout_feedback", "version": 1,
  "surface": "timeline_dock", "scenario": "small_queue_3_actors",
  "dock_size": [420, 720], "ui_scale": 1.0,
  "edited": [{"id": "<ui_metric_id>", "param": "custom_minimum_size.x", "old": 60, "new": 96}],
  "untouched": ["<ui_metric_id>"], "note": "", "timestamp": "<iso8601>"
}
```

Layout params only。file path / node path / project info は入れません。

---

## Iterations

_None yet._ calibration loop は `manual-optional` (UI_LAYOUT_CALIBRATION_POLICY §6) であり、CI gate ではありません。iteration は実際の tweak-and-bake session が発生したときに追記します。各 entry:

```md
## Iteration <n> — <date> — <surface>

- feedback: docs/ui/calibration_inbox/<file>
- baked: <id / param / new value>
- threshold updates: <EDITOR_UI_CONTRACT.md section>
- untouched: <ui_metric_id list>
```

## Cold-control tracker

| ui_metric_id | surface | consecutive untouched | status |
|---|---|---|---|
| _(iterations が増えたら populate)_ | | | |

