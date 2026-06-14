# EQM-013 SUB_TASKS

## Complexity

Class: C3
Reason:
- 順序という product 中心価値の証明機構 (canonical trace + golden + property tests) を確立する。後続の全 core/policy/demo task の gate がこれに乗る (`DETERMINISM_TRACE_TEST_POLICY.md`)。
- trace-record-kind schema を **open/extensible** にする横断判断 (EQM-014 の `event_line_progressed`/`window_*`、EQM-061 の `closed_by` が harness 改修なしで kind を足せること)。
- golden 承認フロー (明示 flag のみ更新) を test.sh 既存 plumbing に接続する。

Required artifacts: Complexity header / Task Resolution / Scheduled Task Audit / UX (最小) / POLICY (Invariant + Fallback table) / IMPLEMENTATION_PLAN (dependency/test matrix)。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQTrace (canonical recorder) | resolved event 1件=1 record、JSONL 出力 | adopt | `record(fields)` 汎用 + `record_resolved`。`i` resolution index 必須。 |
| canonical encoder (key 再帰 sort) | byte 一致 + 固定 key 順 + 任意 kind 対応 | adopt | 自前 encoder。int/string/bool/array/dict。float は invalid (dev fail-fast)。JSON.stringify の順序/float 表現に依存しない。 |
| open kind schema | 後続 phase が kind を足せる | adopt | recorder は kind 集合を hardcode しない。新 field も sorted-key で安定 serialize。test で証明。 |
| golden approval gate | 固定シナリオの exact match | adopt | `tests/golden/core_scheduler_basic.trace.jsonl`。`--update-golden` flag のときのみ再生成。 |
| property: replay determinism | 同シナリオ2回で byte 一致 | adopt | seeded scenario 生成 → trace 2回 → 同一。別 seed は (ほぼ確実に) 別 trace。 |
| property: permutation invariance | 同 (tick,priority,seq) 集合は挿入順非依存 | adopt | backend 層: 固定 entry を別順挿入 → `ordered()` 一致。 |
| property: snapshot continuity | 中断 trace == 無停止 trace | adopt | 途中 snapshot→restore→継続 が無停止と同一 (EQM-012 連携)。 |
| explanation-as-data 整合 | tie_break.decided_by が comparator と一致 | adopt | §4 core test 最小版。full explanation API は EQM-091。 |
| trace に seed-RNG を内蔵 | — | reject | scheduler RNG は EQM-072。本 task の seed は「シナリオ生成」の決定性であり scheduler 内部乱数ではない。 |
| golden を通常 run で自動更新 | — | reject | policy 違反 (CI 自動更新禁止)。明示 flag のみ。 |

## Scheduled Task Audit

新規 scheduled task なし。次の依存解放は EQM-014 (event model semantics, depth=decision)。EQM-014 は autonomous loop の **checkpoint** (§8.3) であり、本 task 完了後に停止してユーザー判断を仰ぐ。trace-kind schema を本 task で open にしておくことで EQM-014 の `event_line_progressed`/`window_*` 追加が harness 改修不要になる。
