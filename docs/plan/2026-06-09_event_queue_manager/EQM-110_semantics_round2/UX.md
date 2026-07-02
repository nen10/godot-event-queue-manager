# EQM-110 UX — semantics round 2

user goal: (1) v1.x 実装者 (autopilot 含む) が SEM だけを読めば Q27–Q43 の決定どおりに実装できる。(2) 凍結契約の「宣言のみ実装漏れ」が再発したら標準検証が FAIL する。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. SEM v1.1 に決定を additive 追記 (節単位) | high | low | medium | adopt | v1 決定の不変性を保ち差分審査できる |
| B. 決定を synthesis のみに置き SEM は据え置き | low | high | low | reject | authoritative が分裂し EQM-053 型の写像漏れが再発する |
| C. coverage matrix を docs のみで運用 | medium | high | low | reject | 「宣言のみ」問題の再発。機械 gate が本 round の目的 |
| D. coverage matrix + tools checker を test.sh に配線 | high | low | medium | adopt | implemented 宣言と実 file/test の乖離を FAIL にできる |

## Operation steps (実装者の導線)

1. queue の Phase 11 task を開く → acceptance に「凍結契約 ID (SEM §/coverage row)」が明記されている。
2. SEM の該当節を読む → 決定 (data model / API 形 / trace 語彙 / 既定動作) が一意に書かれている。
3. 実装後、coverage matrix の該当 row を `implemented` に flip し、file/test 列を実 path にする → checker が存在を検査する。

## 採用/廃止 UX

- 採用: 契約→task→実装→test の単一対応表 (coverage matrix) を設計文書の隣に置く。
- 廃止 (hack): 「SEM §16 の散文だけで実装 phase に委ねる」運用。今回の drift 源。
- 既存 UX との干渉: なし (docs + tools 追加のみ。test.sh は gate 1 つ追加)。
