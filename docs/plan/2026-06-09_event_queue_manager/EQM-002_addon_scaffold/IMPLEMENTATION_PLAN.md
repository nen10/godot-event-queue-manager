# EQM-002 IMPLEMENTATION_PLAN

## Scope

最小 addon scaffold を作り、clean consumer project で headless smoke が PASS することを示す。runtime のドメインロジックは含めない (EQM-010 以降)。

## 変更対象ファイル

- `addons/event_queue_manager/plugin.cfg` — plugin manifest。
- `addons/event_queue_manager/plugin.gd` — `@tool extends EditorPlugin` 最小。
- `addons/event_queue_manager/runtime/eq_version.gd` — `EQVersion` (版 + 最小 Godot)。
- `test_project/project.godot` — clean consumer、plugin enabled、features 4.2。
- `test_project/tests/run_all.gd` — headless smoke runner。
- `test_project/addons/event_queue_manager` — root addon への相対 symlink。

## 実装 steps

1. addon 本体 (plugin.cfg / plugin.gd / runtime/eq_version.gd) を作成。
2. test_project (project.godot / tests/run_all.gd) を作成。
3. `test_project/addons/event_queue_manager` を root addon へ symlink。
4. `./tools/test.sh` を実行し PASS を確認。
5. Godot 生成物 (`.godot/`) が gitignore で除外されること、tracked file 改変が無いことを確認。

## Test path

- `./tools/test.sh` → Godot headless で `test_project/tests/run_all.gd` を実行、exit 0 / RESULT: PASS。
- smoke 検証内容: plugin.cfg 到達 / eq_version.gd load / engine ≥ floor。

## docs 更新

- queue proof log と self-review に結果記載。

## Completion checklist

- [ ] addon が clean consumer project で enable 可能 (plugin.cfg + project.godot enabled)。
- [ ] `./tools/test.sh` が scaffold smoke を実行し PASS。
- [ ] 最小 Godot 版が plugin/runtime/project.godot に宣言され、smoke が実行版を記録。
- [ ] tracked file の意図しない改変や Godot 生成物の混入が無い。
- [ ] clean-load smoke path が self-review に記載。
