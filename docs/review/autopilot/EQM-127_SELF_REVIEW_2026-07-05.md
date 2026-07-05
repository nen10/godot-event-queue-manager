# EQM-127 Self Review — snapshot v3 + replay 証明拡張

date: 2026-07-05 / task: EQM-127 / pattern: P2 (codex 委譲 1 run + orchestrator 検収)

## Acceptance check (SEM v1.2 §10.1)

- [x] schema_version 3: additive tables `relations` / `state_algebra` (未接続時は空 dict)。line modifiers = event_lines 内包 (EQM-121)、provenance = reservation dict 内包 (EQM-123)、phase checkpoints = boundary-gated save で常に空 (windows と同根) — table 不要の判断を doc comment に固定。
- [x] v1/v2 bundle は欠落 table = 空で load (migrator 流儀)。v4 = 安定拒否。
- [x] verify-before-mutate: 非空 table + 未接続 instance = fault + false (何も適用しない)。relations の maintenance NAMED_PREDICATE 未登録 = fault + false。
- [x] load 適用は `restore()` (無 trace) — `state_wrapped` 無発火 test で証明 (EQM-121 申し送りの消化)。
- [x] roundtrip 証明: relations + state_algebra + modifier 付き line + provenance 付き reservation を跨いで同一状態。
- [x] gate PASS ×2 (files=67 checks=1270; coverage 30/31)。

## 委任と検証

- codex 納品は契約準拠。scope 外の既存 test 失敗 1 件を正しく報告して停止 (規律どおり)。
- orchestrator 対応 2 件 (既存 v2 test の version 昇格):
  1. 「bundle is schema v2」固定 assert → 現行 schema (3) へ (v2 挙動は load 互換 test が担う)。
  2. **「新 schema 拒否」の検体が `schema_version: 3` のまま** — v3 が合法になった今、restore 失敗による偽陽性 pass に化けるため検体を 4 へ更新 (テストの意図を保存)。

## 申し送り

- state_algebra の接続規約 (acceptance が `EQStateAlgebra.new(rr.lines)` を作って `rr.state_algebra` へ) は EQM-128 の manual/dogfood で標準形として提示する。
