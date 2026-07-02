# EQM-118 SUB_TASKS — reducibility 再証明 (product 経路)

## Complexity

Class: C3
Reason: EQM-053 の縮小 (テスト内手書き sim・order 配列比較) を、product の conditions + event-line pipeline による trace 由来比較へ置き換える。product 変更は「submit 時点も評価点」の 1 点 (level 意味論の帰結、SEM §5.4 追記)。

## Task resolution

| task 候補 | 目標/UX | 採否 | 概要 |
|---|---|---|---|
| A. CTB / Energy / Wait-Turn を product pipeline で構成 | SEM §16.1 | 採用 | per-entity line (rate=speed / rate=-1) + 条件 gate 済み予約 + 解決時 reset/spend の acceptance loop。priority は dedicated と同じ (speed / 0 / agility) |
| B. trace 由来比較 | acceptance「order 配列でなく trace」 | 採用 | 両 canonical trace の `resolved` record 部分列 (tick, actor, priority) の同一性。tie-break/speed/delay matrix + 非約数 speed (EQM-053 と同 matrix) |
| C. product 経路の golden fixture | 決定性資産 | 採用 | `reducibility_ctb_pipeline` case (--update-golden 手続き、初回 baseline を self-review 記録) |
| D. submit 時点評価 (product 補完) | 整合の前提 | 採用 | 初期 ready (wait=0 等) が dedicated の seed (due=0) と一致するために必要。level 意味論の帰結として SEM §5.4 に追記 |
| E. EQM-053 の旧 test の削除 | — | 不採用 | 旧 test は「dedicated ↔ 抽象 per-tick sim」の等価を守る別の層。product 証明は本 task の新 test が担う (両輪) |
| F. 4X / phase / stack 系の product 再証明 | — | 不採用 | coverage matrix の写像検証は COV が保持。reducibility 契約の対象は CTB/energy/wait-turn (SEM §16.1) |

Scheduled task: なし。
