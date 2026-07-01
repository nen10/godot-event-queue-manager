# Simple UX Review

作成日: 2026-06-28

対象: Event Queue Manager v1.0 RC の addon 利用体験。特に、単純な turn-order 導線が単純なまま使えるか、Editor/UI 導線が期待通り成立しているかを確認した。

## 結論

**runtime/API と Add Node までの simple UX は成立しています。Editor 内で設定・preview・template 作成まで完結する UX はまだ成立していません。**

単純なゲーム開発者は、`EQManager`、`EQConfig`、concrete policy、`turn_ready`、`finish_action` だけで CTB/Fixed/Energy/Wait Turn の行動順を動かせます。L2 reservation や L3 event-line は simple path に漏れていません。

一方で、Godot Editor 上の addon として期待される「config を選ぶ」「timeline dock を開く」「template generator を dialog から使う」導線は、Control と test harness はあるものの、`plugin.gd` で dock/menu mounting が v1.x follow-up と明記されています。GUI 主導の simple UX としては未完です。

## 監査方法と制約

確認したもの:

- `README.md`
- `docs/ja/manual/*`
- `docs/ui/EDITOR_UI_CONTRACT.md`
- `docs/ui/EDITOR_STATE_MATRIX.md`
- `docs/ja/manual/ui_execution_paths.md`
- `addons/event_queue_manager/plugin.gd`
- `addons/event_queue_manager/runtime/*`
- `addons/event_queue_manager/editor/*`
- `test_project/tests/ui_headless/*`
- `tests/golden/api_surface.json`

制約:

- スクリーンショットに基づく完全な Product Design audit は実施できていません。理由は、対象の Editor surfaces が Godot Editor に mount されておらず、Browser で操作できる UI でもないためです。
- 代わりに、実装コード、UI contract、headless UI metric tests、manual execution path の確認を根拠にしました。
- focus traversal、screen reader、実際の Godot Editor 内レイアウト、マウス操作の快適さは、このレビューだけでは断定できません。

## Flow Health

| step | 利用者の作業 | health | 根拠 |
|---|---|---|---|
| 1 | addon を入れて plugin を有効化する | 良好 | `plugin.cfg`, `README.md` |
| 2 | `EQManager` を scene に追加する | 良好 | `plugin.gd` が custom node type を登録 |
| 3 | `EQConfig` と concrete policy を用意する | API は良好、GUI は不足 | `EQConfig.validate()` は明示的。汎用 `config_panel` 実装は未確認 |
| 4 | actor を登録し、policy が読む stats を入れる | 良好 | `EQManager.register_actor()`, demos |
| 5 | `seed()` して `turn_ready` -> `finish_action()` で進める | 良好 | manager suspend contract が明確。quickstart と demos に例あり |
| 6 | 次の順序を preview する | API / runtime HUD は良好、Editor Dock は不足 | `EQPrediction`, `EQTimelineHud`, `EQTimelineDock`; dock mounting は follow-up |
| 7 | 順序理由を見る | Control は良好、Editor 到達は不足 | `EQDebugInspector` と tests はあるが mount なし |
| 8 | Action Resolution template を使う | Control は部分成立、Editor 到達は不足 | `EQTemplateGenerator` は sample separation 済み。dialog としての起動導線なし |
| 9 | reservation / reaction / rollback を使う | 強力だが simple ではない | L2 opt-in としては妥当。初心者主導線ではない |

## 良い点

1. **simple path に L2/L3 が漏れていない。** `EQManager` + `EQConfig` + policy で turn-order が完結する。API surface gate も layer leak を検出する。
2. **hidden fallback が少ない。** config missing、invalid policy、sample artifact は明示 state / validation になっており、silent bundled default に流れない。
3. **projection-first UI は方針が強い。** timeline は `EQPrediction` の投影として検証され、UI 側で並びを再計算しない。
4. **sample separation が明確。** `EQTemplateGenerator.generate()` は sample、`duplicate_to_project()` が production bridge。sample が production slot を silent に満たさない。
5. **validation と error taxonomy が利用者に返る。** `EQValidation` / `EQError` によって、失敗が code として扱える。

## UX Issues

### P1: Editor surfaces が利用者導線に mount されていない

`EQTimelineDock`、`EQDebugInspector`、`EQTemplateGenerator` は実装・headless test 済みですが、`plugin.gd` は `EQManager` custom node type の登録だけを行います。利用者は plugin を有効化しても、dock/menu からこれらの UI を開けません。

影響:

- 「アドオンを使う」体験がコード中心になる。
- README や manual で editor UI を期待した利用者は、入口を見つけられない。
- UI metric tests が守っている品質が、実際の editor 体験としてまだ届かない。

推奨:

- v1.x の最優先 follow-up として `add_control_to_dock` / menu action / resource picker wiring を実装する。
- mount 済み surface ごとに、現在の headless tests に加えて最低限の EditorPlugin smoke test または manual proof を残す。

### P1: `config_panel` は契約にあるが実装入口がない

`EDITOR_UI_CONTRACT.md` と `EDITOR_STATE_MATRIX.md` には `config_panel` が定義されていますが、実体の `addons/event_queue_manager/editor/config_panel.gd` は見当たりません。

影響:

- simple path の最初の難所である `EQConfig` 作成が、GUI では支援されない。
- policy 選択を Editor で完結できない。

推奨:

- `config_panel` を実装するか、未実装であることを UI contract / manual の目立つ位置に明記する。
- 最小版でも `EQConfig` picker、policy picker、`validate`、validation list だけを提供する。

### P2: `finish_action` と `wait_close` の二経路は混同しやすい

dogfood report でも確認されている通り、manager-driven loop では `manager.finish_action()` が suspend を解除します。`EQActionResolutionPolicy.wait_close()` は explicit-transaction flow 用で、manager suspend は解除しません。

影響:

- AP / wait を使い始めた利用者が、1 turn 後に進まない状態を作りやすい。

推奨:

- manual では現在のように明記する。
- 将来 API として `manager.wait_close(...)` または misuse を検出する validation/fault を検討する。

### P2: Template generator は Action Resolution 固定

`EQTemplateGenerator` は Action Resolution Turn-Based template に特化しています。CTB、Energy、Wait Turn の simple starter は GUI template から生成できません。

影響:

- 単純な turn-order から始めたい利用者ほど template の恩恵を受けにくい。

推奨:

- v1.x で CTB / Fixed / Energy / Wait Turn の starter config template を追加する。
- その際も sample -> duplicate-to-project の二段階は維持する。

### P3: Runtime HUD は localization key がそのまま表示される可能性がある

`EQTimelineHud` は `EQ_TIMELINE_STALE` と `EQ_TIMELINE_EMPTY` を label text に入れています。コメント上は localizable key ですが、現コードでは `tr()` 呼び出しではありません。

影響:

- translation setup がない project では key 文字列がそのまま表示される。

推奨:

- `tr("EQ_TIMELINE_STALE")` / `tr("EQ_TIMELINE_EMPTY")` にするか、fallback として自然文を出す。

## Accessibility Risks

- UI contract は boolean text 禁止、icon / badge / tooltip 優先を定めており、構造的には良い。
- ただし、placeholder texture や glyph badge が実際の screen reader / keyboard focus で十分かは未確認。
- Editor surfaces が mount されていないため、実際の Godot Editor 内での focus order、tab navigation、dock resizing、high DPI、theme contrast は確認できていない。
- `EQTimelineHud` の stale 表示は glyph + text key なので、翻訳または accessible label の整備が必要。

## Simple UX 判定

| 観点 | 判定 |
|---|---|
| L0/L1 API の単純さ | 達成 |
| 深い層が simple path に漏れないこと | 達成 |
| hidden sample / fallback の排除 | 達成 |
| config 作成のわかりやすさ | 部分達成 |
| Editor addon としての GUI 到達性 | 未達 |
| preview / explanation の実装品質 | Control と tests は達成、実利用導線は未達 |
| AP / reservation の学習しやすさ | 部分達成 |

## 推奨する次の UX タスク

1. `EQTimelineDock`、`EQDebugInspector`、`EQTemplateGenerator` を EditorPlugin から開けるようにする。
2. `config_panel` の最小実装を追加する。
3. CTB / Fixed / Energy / Wait Turn の starter template を追加する。
4. `finish_action` / `wait_close` の misuse を API または validation で検出する。
5. `EQTimelineHud` の localizable text を `tr()` または fallback 文言にする。
6. 実際の Godot Editor 上でスクリーンショット付き UX audit を再実施する。

## Final Verdict

Event Queue Manager は、コードで使う runtime addon としては simple UX の核を実現しています。特に、単純な turn-order が L2/L3 を知らずに完結する点は強いです。

ただし、利用者が「Godot Editor のアドオン UI」として期待する導線は未完成です。v1.0 RC の UX 表現としては、**API-first addon with tested UI Controls** と説明するのが正確です。**Editor-complete addon** と言うには、dock mounting と config panel が必要です。

