# EQM-120 SUB_TASKS — semantics round 3 (Q44–Q54 確定 + queue Phase 12 起票)

## Complexity

Class: C4
Reason:

- 複数設計文書 (SEM v1.2 / registry / coverage) と外部 repo 同期 (EBS 引き渡し原本) にまたがる。
- 決定 16 fork の確定記述であり、誤写像は v1.2 実装全 task に波及する。
- 新規サブシステム (状態代数 / 関係グラフ) の契約新設を含むが、runtime code は変更しない。

Required artifacts:

- C3 artifacts + Fallback/Mirror table + State/Invariant table + Scheduled Task Audit (本 file)。

## Task resolution

| task 候補 | 目標/UX | 採否 | 概要 |
|---|---|---|---|
| A. SEM v1.2 確定記述 | Q44–Q54 決定を authoritative 契約へ | 採用 | §4.8/§5.7/§6.4–6.5/§7.2/§8.2–8.4/§10.1/§11/§13.1/§16.2 を additive 追記 |
| B. registry finalization | Q44–Q54 の status 確定 + 相談ラウンド3 記録 + pointer 表 | 採用 | user意見欄へ対話決定を記入 |
| C. synthesis 記録 | 決定根拠の永続化 (前 round と同形式) | 採用 | `docs/review/EVENT_MODEL_OPEN_QUESTIONS_SYNTHESIS_2026-07-05.md` |
| D. coverage reserved 行 | 新契約→task の帳簿 (再発防止 gate に乗せる) | 採用 | 10 行 reserved + Deferred 節の bundle 項更新 |
| E. queue Phase 12 起票 (EQM-121..128) | 自律実装の入力 | 採用 | 線形鎖。EQM-121 READY / 以降 BACKLOG |
| F. EBS 引き渡し原本の同期 | 依頼元が確定事項と自側宿題を把握 | 採用 | 相談ラウンド3 表 + R03/R07 確定注記 |
| G. SEM の状態代数を独立文書化 | — | 不採用 | authoritative 分裂 (UX.md B と同根) |
| H. 実装 task の並列鎖化 | — | 不採用 | 契約間依存 (代数→pipeline→bundle) が実際に線形。前 round 実績も線形 |

## Scheduled Task Audit (→ IMPLEMENTATION_QUEUE Phase 12)

| id | dependency | 概要 |
|---|---|---|
| EQM-121 | EQM-120 | 状態代数 backend (inv ペア宣言 + 相殺の符号付き line / 排他 / 共存、wrapper 合成構造、rate modifier-stack、寿命 3 種 acceptance) |
| EQM-122 | EQM-121 | 関係グラフ backend (関係型宣言 / 維持条件 sweep / 直列縫合 / invalidate_actor 連動 / trace kinds) |
| EQM-123 | EQM-122 | pipeline 拡張 (target 展開 + メタ/コスト停止、効果パターン変換フック + 多重適用、provenance 連鎖) |
| EQM-124 | EQM-123 | composite atomic bundle (member 全 effect → 単一 sweep、§7.1 staging 解除) |
| EQM-125 | EQM-124 | メタレベル + window premature close (`cause: intervention`、回避判定、迎撃 golden) |
| EQM-126 | EQM-125 | 操作フェーズ再帰 (sub-checkpoint / ループ検出 / 巻き戻し + 入力解除、水鏡 golden) |
| EQM-127 | EQM-126 | snapshot v3 + replay 証明拡張 (modifier / relation / provenance / checkpoint tables) |
| EQM-128 | EQM-127 | Q54 確認系 acceptance 束 + authoring surface 追加 + manual/dogfood 更新 (coverage 最終 flip) |
