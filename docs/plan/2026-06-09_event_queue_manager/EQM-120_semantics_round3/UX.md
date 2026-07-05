# EQM-120 UX — semantics round 3 (EBS 拡張ラウンド Q44–Q54)

user goal: (1) v1.2 実装者 (autopilot 含む) が SEM だけを読めば Q44–Q54 の決定どおりに実装できる。(2) EBS 側 (依頼元) が引き渡し原本だけを読めば、確定事項と自側に残る宿題 (メタレベル値付け・変換 validation) を把握できる。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. SEM v1.1 に v1.2 節を additive 追記 | high | low | medium | adopt | EQM-110 と同型。v1/v1.1 決定の不変性を保ち差分審査できる |
| B. 拡張を別文書 (EXTENSION_SEMANTICS) に分離 | low | high | low | reject | authoritative の分裂。EQM-053 型の写像漏れ再発源 |
| C. 相談決定を registry の user意見のみに置く | low | high | low | reject | 「宣言のみ」再発。coverage gate に乗らない |
| D. coverage matrix へ reserved 行を同 commit 追加 | high | low | low | adopt | checker の「COMPLETE task の reserved 残留 FAIL」で実装漏れを機械防止 |

## Operation steps (実装者の導線)

1. queue Phase 12 の task を開く → acceptance に凍結契約 ID (SEM v1.2 § / coverage row) が明記されている。
2. SEM v1.2 の該当節を読む → 決定 (data model / 段 / 順序規則 / trace 語彙 / 既定動作) が一意に書かれている。
3. 実装後、coverage row を `implemented` に flip し実 path を入れる → checker が存在を検査する。

## 採用/廃止 UX

- 採用: 依頼 R01–R12 → registry Q44–Q54 → SEM v1.2 § → queue task → coverage row の単一連鎖。
- 採用: EBS 引き渡し原本への相談ラウンド記録の同期 (EBS 側が EQM repo を読まずに追える)。
- 廃止 (hack): 「依頼文書の散文を実装 phase が直接解釈する」運用 — 必ず SEM を経由する。
- 既存 UX との干渉: なし (docs + queue 追加のみ。L0/L1 surface 不変、拡張は全て L2/L3 opt-in)。
