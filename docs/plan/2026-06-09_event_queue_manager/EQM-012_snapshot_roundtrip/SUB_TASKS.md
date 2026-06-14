# EQM-012 SUB_TASKS

## Complexity

Class: C3
Reason:
- 2 ファイル (EQSnapshot + EQScheduler 追補) だが、**snapshot schema contract** (schema_version + 未知 version の stable load error) を確立し、EQM-013 (trace continuity)・EQM-085 (save/load rebind)・EQM-103 (compat stance) が依存する。
- 「何を serialize するか」(live state vs stale lazy-deletion artifact) の境界判断を含む。

Required artifacts: Complexity header / Task Resolution / Scheduled Task Audit / UX (最小) / POLICY (Invariant + Fallback table) / IMPLEMENTATION_PLAN (dependency/test matrix)。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQSnapshot (format authority) | schema_version 定数 + validate + load 結果コード | adopt | `SCHEMA_VERSION=1`、`validate(data)->Load{OK,UNKNOWN_VERSION,MALFORMED}`、`describe`。format/version の単一権威。 |
| EQScheduler.snapshot() | live state を plain Dictionary 化 | adopt | current_tick / next_event_id / next_sequence / entries(to_dict)。 |
| EQScheduler.restore() | validate→build→commit | adopt | error 時 scheduler 不変。OK 時のみ clear + 再構築。`_generation` は entry から再構築。 |
| stale entry を compact する | snapshot は live state のみ | adopt | lazy-deletion artifact は観測意味を持たない。serialize は実装詳細の漏れになる。 |
| `_generation` を別途 serialize | generations 復元 | reject | live entry が generation を保持。entry から再構築すれば invariant が構造的に保証され冗長 map を持たない。 |
| 未知 version で例外/crash | — | reject | RUNTIME_RESILIENCE: stable load error。code 返却 (fail-safe)、dev は assert OK で fail-fast。 |
| restore を破壊的に先行実行 | — | reject | error 時に scheduler が壊れる。validate→build(非破壊)→commit の順で不変保証。 |

## Scheduled Task Audit

新規 scheduled task なし。次の依存解放は EQM-013 (trace determinism harness)。EQM-013 の「snapshot continuity holds」property は本 task の roundtrip 契約に乗る。malformed-entry-within-valid-version の fail-safe 強化は EQM-020 (error taxonomy) / EQM-022 (resilience modes) が所有 (本 task では非 acceptance、self-review に既知制約として記録)。
