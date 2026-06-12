# UI Layout Calibration Policy (tweak-and-bake)

対象: Event Queue Manager editor UI の layout・サイズ・表示パラメータ
目的: 「ユーザーが UI を直接さわって直し、その結果を構造化データとして開発へ戻す」loop を定義し、screenshot や口頭指示に依存しない layout 改善経路を作る。

上位方針: `docs/devflow/policy/UI_TESTABILITY_POLICY.md` (layer L5)

---

## 0. 名称と既知手法

この loop 全体に一致する確立した単一名称は存在しない。構成要素ごとの既知手法:

| 構成要素 | 既知の呼び名 |
|---|---|
| 実行中に UI / パラメータを直接編集する | live tuning / tweakables / debug menu (ゲーム業界)、Unreal Remote Control、Dear ImGui 系 debug UI |
| 編集結果を成果物 (code / theme) に書き戻す | bake / write-back。Unity の play-mode 編集値保存ツール、design token round-trip に相当 |
| 編集結果を新基準として受け入れ、妨害する test を更新する | approval testing (golden master) の baseline update。snapshot test の update 運用 |
| 触られなかった項目を履歴化し品質再評価する | UI usage telemetry / dead-control detection の editor 内オフライン版 |

総称するなら human-in-the-loop layout calibration。本 project ではこの loop を **Layout Calibration Loop (tweak-and-bake)** と呼ぶ。

## 1. Loop 全体

```text
1. calibration tab を有効化 (debug-only)
2. ユーザーが surface 単位で layout param を編集 (live 反映)
3. "Copy Layout Feedback" -> 構造化 JSON を clipboard へ
4. 開発側 (agent) が JSON を bake:
   a. code / theme / custom_minimum_size へ反映
   b. EDITOR_UI_CONTRACT.md の threshold を更新
   c. 変更を妨害する test を新基準へ更新 (削除は理由必須)
5. ledger へ記録。untouched param は履歴へ
6. 連続 N iteration 触られなかった control -> cold-control 候補として品質再評価へ
```

## 2. Calibration tab 要件

- 場所: 各 dock の debug-only tab。`EQ_EDITOR_CALIBRATION=1` 等の明示 flag でのみ表示する。
- 単位: `ui_metric_id` を持つ Control ごとに、編集可能 param を列挙する。
- 編集可能 param (初期 set):

```text
custom_minimum_size.x / .y
size_flags_horizontal / vertical (選択式)
theme constant: separation / margin
font_size (表示確認用)
visible (collapse 検討用)
split_offset (SplitContainer)
```

- 編集は live で Control に反映する。保存はしない (bake が唯一の保存経路)。
- Reset per-control / per-surface を持つ。
- calibration tab 自体も no-op button audit の対象とする (Copy / Reset は実効果を持つ)。

## 3. Feedback JSON schema

```json
{
  "kind": "eq_layout_feedback",
  "version": 1,
  "surface": "timeline_dock",
  "scenario": "small_queue_3_actors",
  "dock_size": [420, 720],
  "ui_scale": 1.0,
  "edited": [
    {"id": "timeline.row.actor_label", "param": "custom_minimum_size.x", "old": 60, "new": 96},
    {"id": "timeline.list", "param": "theme_constant.separation", "old": 2, "new": 4}
  ],
  "untouched": ["timeline.row.cause_icon", "config.validate_button"],
  "note": "<ユーザー自由記述 optional>",
  "timestamp": "2026-06-13T00:00:00"
}
```

規則:

- layout param のみを含める。file path / node path / project 情報を含めない。
- `untouched` は編集セッション中に一度も変更されなかった `ui_metric_id` の列。
- `scenario` / `dock_size` / `ui_scale` を必ず含める。同じ編集でも文脈が違えば別 feedback である。

## 4. Bake 手順 (開発側)

1. feedback JSON を `docs/ui/calibration_inbox/<date>_<surface>.json` として保存する。
2. `edited` を実装へ反映する。magic number の直書きではなく、名前付き constant / theme へ。
3. 反映値が metric threshold と矛盾する場合、`EDITOR_UI_CONTRACT.md` の threshold を更新し、変更理由を同 file に記録する。
4. 妨害 test の扱い:
   - test が旧 threshold を hard-code している -> 契約参照へ書き換える。
   - test が旧 UX を保護している -> UX_PATH_REDUCTION_POLICY.md と PROJECT_PROFILE の test 原則に従い更新または削除。削除は self-review に理由を残す。
5. ledger に iteration entry を追記する。
6. 標準検証 (`./tools/test.sh`) を通す。

## 5. Ledger と cold-control 規則

`docs/ui/LAYOUT_CALIBRATION_LEDGER.md`:

```md
## Iteration <n> — <date> — <surface>

- feedback: docs/ui/calibration_inbox/<file>
- baked: <id / param / new value の列>
- threshold updates: <contract section>
- untouched: <id の列>
```

cold-control 規則:

- ある surface が calibration された iteration において、連続 3 回 untouched の control を **cold** と分類する。
- cold control は次のいずれかの follow-up 候補として queue 化を検討する:
  - 表示の簡素化 (icon 化、collapse)
  - 機能の再検討 (本当に必要か)
  - 計測解像度の見直し (param が粗すぎて触れなかった可能性)
- cold = 即削除ではない。判断は task packet の UX.md candidate matrix で行う。

## 6. 安全規則

- calibration tab は normal mode で不可視であること (P0_FAIL: 通常 UI への露出)。
- calibration の編集結果は source of truth ではない。bake されない編集は破棄される。
- feedback JSON は layout param 以外を含まない。
- calibration は CI gate ではない。自動 loop を止める根拠にしない (`manual-optional` 扱い)。

## 7. Acceptance (calibration 関連 task)

- flag なしで tab が現れないことの test。
- Copy Layout Feedback が schema 準拠 JSON を生成することの test。
- bake 実施時は ledger entry が残ること (self-review で確認)。
- threshold 変更は契約文書の更新と同時であること。
