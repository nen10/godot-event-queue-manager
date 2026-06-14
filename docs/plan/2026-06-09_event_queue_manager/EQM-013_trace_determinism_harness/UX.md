# EQM-013 UX

利用者は addon 開発者/後続 task。trace は「順序が壊れていないこと」を機械的に示す観測物であり、UI ではない。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. resolved 1件=1 JSONL record | high | low | low | adopt | policy §1。diff 可能、行単位で regression 局所化。 |
| B. canonical key 順 = 再帰 lexicographic sort | high | low | low | adopt | 固定順かつ任意 kind に対応。新 field でも安定。 |
| C. golden 更新は `--update-golden <case>` のみ | high | low | low | adopt | policy §2。通常 run は read-only 比較。 |
| D. record(fields) を汎用にする | high | low | low | adopt | 後続 kind を harness 改修なしで追加。 |
| E. 失敗時に actual trace を run dir へ出力 | medium | low | low | adopt | diff report (policy §2/§6) を可能にする。 |
| F. trace に float/wall-clock/address を許す | — | high | — | reject | canonical 違反。非決定性の温床。 |

## User goal

同 seed・同入力で trace が byte 一致し、golden と exact match することを通常 `./tools/test.sh` で確認できる。受容された変更のみ明示 flag で golden を再 baseline できる。

## Operation steps

1. `var tr := EQTrace.trace_run(scheduler)` — scheduler を解決し尽くして canonical trace を得る。
2. `tr.to_jsonl()` — byte 決定的な JSONL を得る。
3. `./tools/test.sh` — golden 比較 + property test を実行 (通常は read-only)。
4. 受容された変更時のみ `./tools/test.sh --update-golden core_scheduler_basic` で再生成し、self-review に diff 要約と理由を記載する。

## 採用 / 廃止

- 採用: JSONL canonical record、再帰 sort key、明示 flag golden 更新、汎用 record、失敗時 actual 出力。
- 廃止 (hack 化しない): 通常 run での golden 自動更新、float/wall-clock/address の混入、kind ごとの hardcode 分岐。

## 既存 UX との干渉

新規 `EQTrace`。scheduler API は不変 (trace は観測であり scheduler を変更しない)。`tools/test.sh` は run 出力 dir を Godot runner へ渡す env を追加するのみ (既存 `--update-golden` plumbing を利用)。
