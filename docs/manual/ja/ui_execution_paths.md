# UI 実行パス確認

この章は、`docs/manual/` 上の実施項目について、現在のコードベースから UI で到達できるかを確認した結果です。結論として、runtime/API と demo は広く成立しています。一方、Editor UI は headless-testable な Control と契約が中心で、Godot Editor への実際の dock/menu mounting は `plugin.gd` 上で v1.x follow-up とされています。

## 判定基準

| status | 意味 |
|---|---|
| 成立 | 実装済み UI / Godot Editor 導線から実行できることがコード上確認できる |
| 部分成立 | Control、runtime HUD、または限定的な UI 実装はあるが、汎用導線や Editor mounting が未完 |
| 未成立 | API / contract / test はあるが、UI から実行する実装は見当たらない |
| 対象外 | マニュアル上の項目が game code / runtime API として意図されており、UI 操作ではない |

## 全体所見

- `addons/event_queue_manager/plugin.gd` は `EQManager` custom node type を登録します。したがって、plugin 有効化後に Godot Editor の Add Node から `EQManager` を追加する導線は成立しています。
- 同じ `plugin.gd` は、`EQTimelineDock`、`EQDebugInspector`、`EQTemplateGenerator` について「headless UI metric harness で検証される Control」とし、`add_control_to_dock` や `EditorResourcePicker` wiring は v1.x follow-up と明記しています。つまり、Editor dock として開く導線は現状成立していません。
- `EQTimelineDock` と `EQTemplateGenerator` は UI Control として実装され、button wiring や projection integrity は `test_project/tests/ui_headless/` で検証されています。ただし、それらを Godot Editor の menu/dock から開く glue はありません。
- `config_panel` は `docs/ui/EDITOR_UI_CONTRACT.md` と synthetic scenario builder にはありますが、実体となる `addons/event_queue_manager/editor/config_panel.gd` は確認できませんでした。

## 実施項目別の確認表

| manual 項目 | API / demo の成立 | UI 実行パス | 確認根拠 |
|---|---|---|---|
| `EQConfig` を作り、concrete policy を割り当てる | 成立。`EQConfig.validate()` が null/base policy/tie_break を検証する | 部分成立。Action Resolution template だけは config を生成して project に duplicate できる。汎用 config panel は未実装 | `resources/eq_config.gd`, `editor/template_generator.gd`, `test_eq_config.gd`, `test_template_generator.gd` |
| `.tres` として config を保存 / load する | 成立。roundtrip test がある | 部分成立。template generator の `duplicate_to_project()` は `action_resolution_config.tres` を保存するが、任意 config の UI 保存は見当たらない | `test_eq_config.gd`, `editor/template_generator.gd` |
| `EQManager` を scene-local node として追加する | 成立 | 成立。plugin が `add_custom_type("EQManager", "Node", ...)` を呼ぶ | `plugin.gd` |
| actor を `register_actor` し、stats を `data` に入れる | 成立。quickstart/demo/test が使用 | 対象外。actor 登録は game code の責務。汎用 actor editor UI は見当たらない | `runtime/eq_manager.gd`, `demos/ctb_battle/ctb_battle.gd` |
| `manager.seed()` で初期 turn を schedule する | 成立 | 対象外。runtime API として実行する | `runtime/eq_manager.gd`, policy demos |
| `turn_ready` signal を受け、`finish_action()` で turn を閉じる | 成立。manager は suspend を `finish_action()` で解除する | 対象外。game loop / signal 接続の実装項目。専用 UI button は見当たらない | `runtime/eq_manager.gd`, `demos/action_resolution/demo_battle.gd` |
| `advance_frame()` で queue を進める | 成立 | 対象外。game loop 用 API | `runtime/eq_manager.gd`, demo `run_trace()` |
| 次の turn を preview する (`EQPrediction`) | 成立。prediction は live queue を mutate しない | 部分成立。runtime HUD `EQTimelineHud.bind()` と editor Control `EQTimelineDock.set_preview()` はある。Editor dock mounting は未実装 | `runtime/eq_prediction.gd`, `runtime/ui/eq_timeline_hud.gd`, `editor/timeline_dock.gd`, `test_timeline_dock.gd` |
| Timeline Preview Dock の refresh | API/Control として成立 | 部分成立。`timeline.refresh_prediction` button は Control 上で wired。Editor Dock としての到達導線は未成立 | `editor/timeline_dock.gd`, `test_editor_interaction_contract.gd` |
| policy をジャンルから選ぶ | demo/API は成立。各 demo は public API で policy を作る | 未成立。ジャンル別 policy picker UI は確認できない。template generator は Action Resolution 固定 | `docs/manual/policy_selection.md`, `demos/*`, `editor/template_generator.gd` |
| demo を copy / 実行する | 成立。golden-tested demo がある | 部分成立。`ctb_battle` と `wait_turn_tactics` は `.tscn` がある。他は script/headless demo として確認できる | `demos/`, `test_project/tests/debug_scene/` |
| Action Resolution template を生成する | 成立 | 部分成立。`Generate` と `Duplicate To Project` button は Control 上で wired され、sample separation も test されている。Editor dialog として開く導線は未実装 | `editor/template_generator.gd`, `test_template_generator.gd` |
| `EQActionDefinition` を作り、reservation kind を設定する | 成立 | 未成立。専用 authoring UI は見当たらない。Godot の generic Resource inspector で field 編集は可能だが、addon 固有 UI としては未確認 | `resources/eq_action_definition.gd`, `test_eq_action_definition.gd` |
| `EQReservation` を作る | 成立 | 未成立。runtime API として作成する | `runtime/eq_reservation.gd`, `test_eq_reservation.gd` |
| reaction を `EQTriggerEngine.arm()` し、`on_event_resolved()` で fire する | 成立 | 対象外。game-specific effect/sweep point の実装項目。専用 UI はない | `runtime/eq_trigger_engine.gd`, `demos/action_resolution/demo_battle.gd` |
| AP 回復型 loop を `EQActionResolutionPolicy` + `EQManager` で動かす | 成立 | 対象外。game loop/API として実行する | `resources/policies/eq_action_resolution_policy.gd`, `demos/action_resolution/demo_battle.gd` |
| `finish_action` と `wait_close` を使い分ける | 成立。manager-driven loop では `finish_action` が必要 | 対象外。API 上の使い分けであり UI 操作ではない | `runtime/eq_manager.gd`, `resources/policies/eq_action_resolution_policy.gd` |
| `EQTransaction` で draft/rollback/commit する | 成立 | 未成立。transaction draft の UI state は contract/state matrix にあるが、commit/rollback button の実体は確認できない | `runtime/eq_transaction.gd`, `test_eq_wait_commit_boundary.gd`, `docs/ui/EDITOR_STATE_MATRIX.md` |
| order explanation を見る | API/Control として成立 | 部分成立。`EQDebugInspector` Control はあるが、Editor dock mounting と timeline row selection wiring は未実装 | `editor/debug_inspector.gd`, `plugin.gd` |

## manual への反映上の注意

- 日本語版でも、UI からの実行が未成立な項目は「UI でできる」とは書かず、runtime API / demo / Control として説明しています。
- `policy_selection.md` の `EDITOR_UI_CONTRACT.md` config panel 参照は、契約上の surface への参照であり、現時点の実装済み Editor UI ではありません。
- v1.x follow-up として Editor Dock mounting が実装されたら、この章の `timeline_dock`、`template_generator`、`order_inspector`、`config_panel` の status を更新してください。

