# EQM-110 SUB_TASKS — semantics round 2 (Q27–Q43 確定 + coverage gate)

## Complexity

Class: C4
Reason:

- 複数設計文書 (SEM / registry / coverage matrix 新設) と test harness (coverage checker) にまたがる process gate を含む。
- 決定 17 件の確定記述であり、誤写像は v1.x 実装全 task に波及する。
- 実装フローは docs 確定と gate 追加の 2 本。

Required artifacts:

- C3 artifacts + Fallback/Mirror table + State/Invariant table + rejected/deferred の queue 化判定 (本 file の Scheduled Task Audit)。

## Task resolution

| task 候補 | 目標/UX | 採否 | 概要 |
|---|---|---|---|
| A. SEM v1.1 確定記述 | Q27–Q43 決定を authoritative 契約へ | 採用 | §4–§11/§16 を改訂。Q31 は user 相談への reconciliation を含む |
| B. registry finalization | Q27–Q43 を DECIDED(user) 化し pointer に置換 | 採用 | Q31 reconciliation 追記、round 表 status 更新、finalization 追記、Q12 pointer 補正 |
| C. synthesis 記録 | 決定根拠の永続化 (Q01–Q26 round と同形式) | 採用 | `docs/review/EVENT_MODEL_OPEN_QUESTIONS_SYNTHESIS_2026-07-02.md` |
| D. contract coverage matrix + checker | 凍結契約→task→実装→test の対応を機械検査 (再発防止) | 採用 | `docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md` + `tools/check_contract_coverage.py` を test.sh に配線 |
| E. v1.x queue 起票 (EQM-111..119) | 自律実装の入力 | 採用 | Phase 11 として追加。依存は線形鎖 |
| F. SEM の全面書き直し | — | 不採用 | v1 決定は不変。additive 改訂で十分、全面書換は差分審査性を壊す |
| G. coverage checker を後続 task 化 | — | 不採用 | gate は本 task の成果物 (matrix) の enforcement そのもの。分離すると再び「宣言のみ」になる |

## Scheduled Task Audit (→ IMPLEMENTATION_QUEUE Phase 11)

| id | dependency | 概要 |
|---|---|---|
| EQM-111 | EQM-110 | conditions 契約実装 (EQConditionSpec / solve+invalidation schema / named predicate registry / ERROR_CONTRACT 追加) |
| EQM-112 | EQM-111 | event-line backend (line table / rate / 明示 advance / watched sparse polling / `event_line_progressed` / Q43 予算 test) |
| EQM-113 | EQM-112 | 解決 pipeline 統合 (5-step 契約 / chunk 配線 / sweep / Q32 reaction schedule 化 / Q39 invalidate_actor / Q40 expiry event / closed_by 語彙) |
| EQM-114 | EQM-113 | window object model (EQWindow / 暗黙 L0 window / deadline 既定 rollback+close / budget / window trace) |
| EQM-115 | EQM-114 | ordering hook (order_simultaneous / candidates view / golden 被覆; composite bundle は明示 defer) |
| EQM-116 | EQM-115 | race pattern (race-group id / OR 解決 / 敗者一掃 / debug 表示分離の最小実装) |
| EQM-117 | EQM-116 | snapshot v2 + save 境界 enforcement (additive tables / v1→v2 migrator / is_save_allowed 配線 / replay 証明拡張) |
| EQM-118 | EQM-117 | reducibility 再証明 (product event-line model 経由 + golden trace; EQM-053 の縮小を解消) |
| EQM-119 | EQM-118 | L2 authoring surface + dogfood/manual 更新 (反撃準備 .tres 受け入れ基準 / coverage matrix 最終 flip) |
