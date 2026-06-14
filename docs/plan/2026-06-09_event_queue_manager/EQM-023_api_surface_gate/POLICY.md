# EQM-023 POLICY

## 採用判断

- **public/internal naming**: public = leading underscore なし (func/var)。internal = leading underscore。const = UPPER_CASE (public)。class_name 付き file のみ surface 対象。
- **layer map は tool 内 dict + API_SURFACE.md** が単一権威。core/L0/L1/L2/L3。source に class_name があり map に無ければ FAIL (層割当強制)。
- **deterministic export**: surface を sorted JSON で出力 (`tests/golden/api_surface.json`)。通常 run は exact 比較 (read-only)、差分は FAIL。
- **golden 更新は明示** `--update` のみ (DETERMINISM_TRACE_TEST_POLICY 同趣旨)。self-review に差分要約。
- **L3 leak 検出**: L0/L1 class の public signature (func params/return, var type) に L3 class 名が現れたら FAIL (roadmap §3.1)。現状 L3 不在で trivially pass。`--self-test` が synthetic leak を検出して検出器を毎 run 証明。
- **test.sh 結線**: python-checks 区画で `--self-test` と check を実行、非 0 で gate FAIL。`--update-golden api_surface` で `--update` に委譲。

## 不採用判断

- source 全 file への `## @layer` tag 付与 (churn。map+golden 二重チェックで drift は golden diff が捕捉)。
- 通常 run での golden 自動更新。

## 層割当 (初期)

| layer | classes |
|---|---|
| core | EQEntry, EQOrdering, EQScheduler, EQBackend, EQSortedArrayBackend, EQSnapshot, EQTrace, EQError, EQValidation, EQVersion |
| L0 | EQRuntime, EQActorRegistry, EQActorState, EQActionResult |
| L1 | EQConfig, EQPolicy |
| L2 | (Phase 5: reservation) |
| L3 | (Phase 5+: event-line) |

## Invariants

- surface JSON は deterministic (sorted、同入力で byte 一致)。
- public class はちょうど 1 layer を持つ (未割当は FAIL)。
- L3 class 名は L0/L1 の public signature に出現しない。
- golden は通常 run で不変 (read-only)。
- leak 検出器は健全 (`--self-test` が synthetic leak を検出)。

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| surface diff (golden 不一致) | FAIL + diff 表示 | 意図しない API 変更を止める | — | 通常 run で exact 比較 |
| 未割当 public class | FAIL | 層割当強制 (leak 予防前提) | — | map 不在 class で FAIL |
| L3→L0/L1 leak | FAIL | 層分離 (§3.1) | — | `--self-test` synthetic leak |
| golden 更新 | `--update` flag のみ | 明示承認 | — | 通常 run は書かない |
