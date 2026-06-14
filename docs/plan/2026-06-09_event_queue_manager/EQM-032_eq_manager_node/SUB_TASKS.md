# EQM-032 SUB_TASKS

## Complexity

Class: C3
Reason:
- 初の Godot Node + signal 統合 + game-loop driver 契約 (who advances / suspend / await boundary / frame-budget)。
- EQM-030/031 で defer した policy↔runtime 自動委譲をここで結線し L0 flow (register→turn_ready→finish) を提供。
- 新 class (EQManager) + plugin 登録 → API surface 変更。driver 契約は SEMANTICS §14 に記載済み (要整合)。

Required artifacts: Complexity header / Task Resolution / UX / POLICY / IMPLEMENTATION_PLAN (dependency/test matrix)。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQManager (Node) | scene-local facade + 6 signal | adopt | EQRuntime を wrap。queue_changed/event_ready/turn_ready/event_resolved/timeline_advanced/invalid_event_skipped。 |
| policy 自動委譲 | finish_action→policy.on_turn_finished | adopt | EQM-030/031 から defer した結線。L0 ergonomics。 |
| suspend semantics | turn_ready 後は finish_action まで advance しない | adopt | player 入力待ち。`_awaiting_turn` flag。 |
| frame-budget advance | advance_frame(budget) で time-sliced 解決 | adopt | large-battle hitch 回避。order 不変 (determinism)。 |
| invalid actor policy 検出 | configure 時 validation | adopt | base policy / missing を validate で捕捉。 |
| plugin に custom type 登録 | editor から EQManager 追加可 | adopt | add_custom_type / remove。 |
| Node が自前で _process 駆動 | — | reject (default) | consumer が advance を呼ぶ。auto-drive は opt-in (本 task は明示 step/advance_frame)。 |

## Scheduled Task Audit

新規 scheduled task なし。次の依存解放は EQM-033 (prediction)。production Node bridge (save/load rebind, autoload installer, multi-domain signals) は EQM-085 (Phase 8b)。
