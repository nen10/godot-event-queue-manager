# EQM-002 SUB_TASKS

## Complexity

Class: C2
Reason:
- 最小 addon scaffold + clean consumer project + headless smoke runner。bounded。
- 採否のある選択は「addon を consumer project へどう供給するか」と「smoke が何を検証するか」のみ。状態境界小、fallback/mirror なし。

Required artifacts: Complexity header / Task Resolution / Scheduled Task Audit / UX Candidate Matrix / fallback 確認。

## Task Resolution

| 候補 | 目標/UX | 採否 | 概要 |
|---|---|---|---|
| addon plugin.cfg + plugin.gd | clean project で enable できる EditorPlugin | adopt | 最小 @tool EditorPlugin。dock は後 phase。 |
| runtime/eq_version.gd | 版数 + 最小 Godot 宣言の置き場 | adopt | class_name EQVersion、is_supported_engine()。 |
| test_project (clean consumer) | headless smoke + 将来の test runner target | adopt | tools/test.sh の `--path test_project` 契約に一致。 |
| addon 供給方法 = symlink | single source、consumer から res:// で到達 | adopt | `test_project/addons/event_queue_manager -> ../../addons/...`。copy は二重管理で reject。 |
| run_all.gd smoke | clean-load 到達性 + engine floor を検証 | adopt | exit 0/1 で gate に接続。 |

## Scheduled Task Audit

新規 scheduled task なし。次の依存解放は EQM-010 (core event contract)。
