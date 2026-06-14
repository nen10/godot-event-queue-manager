# EQM-010 POLICY

## 採用判断

- **class_name + import pass**: runtime script は `class_name` を宣言する (real project の API ergonomics)。headless では class_name 解決に project import が要るため、`tools/test.sh` が runner 前に `--import` pass を行い `global_script_class_cache.cfg` を構築する。`.godot/` は gitignore なので毎 run import する。
- **cross-file ref は preload const**: ファイル間参照 (eq_ordering → EQEntry) は `preload` const を使い、import 失敗時の壊れ方を明示にする。
- **factory は null 拒否**: `EQEntry.make()` は負 tick で null を返す (push_error しない)。dev fail-fast / shipped fail-safe の surface は scheduler 層 (EQM-011/020)。これにより「出力中の error = 本物の問題」という gate 信号が綺麗に保たれる。
- **test framework 規約**: 各 test file は `extends RefCounted` + `static func run(t)`。`run_all.gd` が `res://tests/**/test_*.gd` を sorted 探索して呼ぶ。assert helper `eq_test.gd` は path load (global 非依存)。
- **masked failure guard**: `tools/test.sh` は runner 出力を `SCRIPT ERROR|Compile Error|Parse Error|Failed to load script` で grep し、exit 0 でも検出時 FAIL にする。

## 不採用判断

- factory での assert 停止 (test 不能・shipped crash)。
- cross-file の素の class_name 依存のみ (import 失敗時に静かに壊れる)。

## Invariants

- 順序 key (due_tick, priority, sequence) は entry 生成後に不変。reschedule は cancel + re-push (Q07/Q08)。
- sequence は push ごとに一意 → 全順序、sort 安定性に非依存。
- ordering に float 不関与。

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| import pass | 毎 run 実行 | class_name 解決 | export template only CI に移れば再評価 | clean checkout で `./tools/test.sh` PASS |
| factory null | error 非送出 | gate 信号維持 | EQM-020 error taxonomy 導入時に code 付与 | 負 tick → null の test |
