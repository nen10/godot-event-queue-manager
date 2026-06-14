# EQM-013 POLICY

## 採用判断

- **canonical trace = resolved event 1件1 record の JSONL** (`DETERMINISM_TRACE_TEST_POLICY` §1)。各 record は resolution index `i`、ordering key (tick/priority/seq, int のみ)、event_id、kind、actor、cause、tie_break を持つ。
- **自前 canonical encoder**。Dictionary は key を再帰的に lexicographic sort して出力 → 固定 key 順 (policy §1.2) かつ任意 kind shape に対応 (open schema)。`JSON.stringify` の順序保証や float 表現に依存しない。
- **float は trace に invalid**。ordering key は int のみ (policy §1.2)。encoder が float を見たら dev fail-fast (`push_error`)。
- **kind 集合を hardcode しない**。`record(fields)` は汎用で、`record_resolved` は便宜。EQM-014 (`event_line_progressed`/`window_opened`/`window_closed`)・EQM-061 (`closed_by`) は新 field を渡すだけで harness 改修不要。
- **golden = exact match approval test**。`tests/golden/core_scheduler_basic.trace.jsonl`。通常 run は read-only 比較。`GODOT_UPDATE_GOLDEN == <case>` のときのみ再生成 (test.sh の `--update-golden <case>` plumbing を利用)。初回 baseline 生成も同 flag 経由で、self-review に明記する。
- **tie_break.decided_by = explanation-as-data**。文字列で理由を再構成せず、comparator が決めた key を構造データで出す。core test で comparator 実装との一致を確認 (policy §4 最小版; full explanation API は EQM-091)。
- **trace は観測であり scheduler を変更しない**。`trace_run` は pop で消費するが、property test は snapshot/restore で非破壊比較する。

## 不採用判断

- 通常 run での golden 自動更新 (policy §2 違反、`repair-now` 相当)。
- float / wall-clock / node path / object address の trace 混入 (canonical 違反)。
- kind ごとの hardcode 分岐 (拡張性を殺す)。
- scheduler 内部 RNG (EQM-072 が所有。本 task の seed はシナリオ生成の決定性のみ)。

## Resource / API / UI 境界

- **public**: `EQTrace`(`record`, `record_resolved`, `to_jsonl`, `records`, `size`, static `trace_run`)。
- **internal**: canonical encoder、decided_by 算出。
- **test infra**: `tools/test.sh` が `EQ_RUN_OUT` (run 出力 dir 絶対パス) を Godot runner へ export。golden test が失敗時 actual を `traces/` へ書く。

## Invariants

- replay determinism: 同入力 → `to_jsonl()` が byte 一致。
- permutation invariance: 同 (tick,priority,seq) 集合は backend 挿入順に非依存で同一 `ordered()`。
- snapshot continuity: 途中 snapshot→restore→継続 trace == 無停止 trace。
- trace の ordering key は int のみ。固定 key 順。
- golden は通常 run で不変 (read-only)。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| `to_jsonl()` | 同入力で byte 一致、key 固定順 | 非決定 serialize | 2回生成して同一、別 seed で相違 |
| golden fixture | 通常 run は read-only 比較 | 自動更新 regression | 通常 run で exact match、更新は flag のみ |
| snapshot continuity | 中断有無で trace 不変 | 復元欠落 | 中断 trace == 無停止 trace (byte) |
| tie_break.decided_by | comparator と一致 | 理由の独自再構成 | due_tick/priority/sequence/terminal の各分岐を assert |
| record kind | 任意 kind が安定 serialize | kind hardcode | future kind を record→sorted-key 出力を assert |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| golden 不在/不一致 | FAIL + 再 baseline 手順を message に提示 | 自動容認禁止 (policy §2) | — | golden 存在 + exact match を assert |
| trace 中の float | `push_error` (dev fail-fast) | canonical 違反 | — | 本 task の trace は int のみ (発火させない) |
| 失敗時の actual trace | `EQ_RUN_OUT/traces/<case>.actual.jsonl` へ出力 | diff report (policy §2/§6) | — | 不一致時に actual を書き出す経路 |
