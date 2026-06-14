# EQM-002 UX

User: addon を導入する Godot 開発者 (consumer)。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| addon を test_project に copy | low | high | medium | reject | source が二重化し drift する |
| addon を root に置き test_project へ symlink | high | low | low | adopt | single source、consumer から res:// 到達、package も root addons/ |
| test_project を作らず root project で test | medium | medium | low | reject | clean consumer load を別 project で示せない (acceptance) |
| smoke で EditorPlugin を headless 起動検証 | low | high | high | reject | EditorPlugin は editor 専用、headless 非活性。clean-load+到達性で代替 |

## Operation steps

1. consumer が addon を `addons/event_queue_manager/` に置く (本 repo では symlink で test_project に供給)。
2. `project.godot` の `[editor_plugins] enabled` に plugin.cfg を加える → editor で有効化。
3. project が clean に load する。
4. `./tools/test.sh` が headless smoke を実行し PASS。

## 採用 / 廃止

- 採用: single-source addon + symlink、clean-load + 到達性 + engine-floor smoke。
- 廃止: copy 供給、headless での EditorPlugin 活性検証。
