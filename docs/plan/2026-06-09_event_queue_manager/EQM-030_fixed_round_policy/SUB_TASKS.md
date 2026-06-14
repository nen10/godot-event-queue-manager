# EQM-030 SUB_TASKS

## Complexity

Class: C3
Reason:
- 最初の concrete EQPolicy。**policy 契約** (`seed` / `on_turn_finished`) を確立し、CTB(EQM-031)/Energy(EQM-040)/Wait(EQM-041)/AP(EQM-052) が乗る L1 拡張点になる。
- EQPolicy base に契約メソッド追加 + 新 class → API surface 変更 (EQM-023 golden 更新を伴う)。

Required artifacts: Complexity header / Task Resolution / Scheduled Task Audit / UX / POLICY (契約 + Invariant) / IMPLEMENTATION_PLAN (dependency/test matrix)。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQPolicy 契約 = seed + on_turn_finished | Fixed/CTB/Energy/Wait/AP 全てが乗る最小契約 | adopt | runtime primitives (register/schedule/advance) の上に policy を実装。runtime 内部は知らない。 |
| EQFixedRoundPolicy | initiative 順・round refresh・removal skip | adopt | seed: round1 全員を due_tick=1, priority=initiative。on_turn_finished: 次 round (current_tick+1) に再投入。 |
| 順序 = (due_tick=round, priority=initiative) を scheduler に委ねる | tie は sequence(登録順) | adopt | 既存 EQOrdering を再利用。初期化なしで決定的。 |
| runtime.finish_action に policy 自動委譲 | L0 ergonomics | defer→EQM-032 | 本 task は policy が runtime primitives を使用、test が seed/on_turn_finished を駆動。runtime 結線は EQManager(EQM-032)。EQM-022 を触らない。 |
| initiative を built-in field 化 | — | reject | actor data["initiative"] から読む (Q16: acceptance 定義)。policy が key を持つ。 |

## Scheduled Task Audit

新規 scheduled task なし。次の依存解放は EQM-031 (CTB policy, 同契約)。EQManager(EQM-032) が policy↔runtime を結線し L0 flow (register→turn_ready→finish) を提供する。
