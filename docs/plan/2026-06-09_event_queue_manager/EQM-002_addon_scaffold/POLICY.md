# EQM-002 POLICY

## 採用判断

- addon の single source は `addons/event_queue_manager/` (root)。`test_project/addons/event_queue_manager` は相対 symlink でそこへ向ける。package 対象も root addons/。
- 最小 Godot は **4.2** を public floor として宣言 (`EQVersion.MIN_GODOT_*`, `test_project/project.godot` features)。dev/CI の実行版は 4.6 で、smoke が実行版を記録・floor 判定する。
- scaffold の smoke は「clean consumer project が load でき、addon が res:// で到達でき、engine が floor 以上」を検証する。EditorPlugin の活性は editor 専用のため headless smoke の対象外。

## 不採用判断

- addon を test_project へ copy しない (drift)。
- headless で EditorPlugin 起動を要求しない。

## 境界 / Invariants

- addon source は 1 箇所 (root)。consumer は symlink/コピーで取り込む。
- test 出力は `.godot_user/test-runs/<run-id>/`。`.godot/`・`.godot_user/` は gitignore 済み。
- smoke runner は exit code で gate に接続する (0 pass / 非0 fail)。

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| test_project の addons symlink | single source の mirror ではなく参照 | drift 防止 | package 化時に dist へ実体 copy する段で再評価 | `./tools/test.sh` が plugin.cfg 到達を検証 |
| 最小 Godot 宣言 4.2 (実行 4.6) | floor は intended、実行は記録 | 古い版未検証を overclaim しない | 旧版 CI 追加時に floor 検証 | smoke が engine_string を記録 |

## Compatibility stance

`replace`: 旧 scaffold は無い (新規)。public contract は本 scaffold から開始。
