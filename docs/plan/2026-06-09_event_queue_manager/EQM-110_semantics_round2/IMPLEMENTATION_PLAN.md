# EQM-110 IMPLEMENTATION_PLAN — semantics round 2

## Scope

Q27–Q43 決定の確定記述 (SEM v1.1 / registry finalization / synthesis) + contract coverage gate (matrix + checker + test.sh 配線) + v1.x queue (EQM-111..119) 起票。製品 runtime code の変更はしない。

## 変更対象ファイル

- `docs/design/EVENT_MODEL_SEMANTICS.md` — v1.1 additive 改訂 (§4/§5/§6/§7/§8/§9/§10/§11/§13/§16/§17)
- `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` — Q27–Q43 finalization (status 表 / → 決定 block / Q31 reconciliation / Q12 pointer 補正)
- `docs/review/EVENT_MODEL_OPEN_QUESTIONS_SYNTHESIS_2026-07-02.md` — 新規 (決定根拠)
- `docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md` — 新規 (契約→task→実装→test)
- `tools/check_contract_coverage.py` — 新規 checker
- `tools/test.sh` — checker 配線
- `docs/plan/2026-06-09_event_queue_manager/IMPLEMENTATION_QUEUE.md` — Phase 11 追加 + proof + pointer

## 実装 steps

1. synthesis 記録を書く (決定対照 + Q31 reconciliation)。
2. SEM v1.1 改訂 (additive; 各節に v1.1 マーク)。
3. registry finalization (status / → 決定 / pointer 表追記 / Q12 補正)。
4. coverage matrix 作成 (契約 group row; v1.0 実装済み row は implemented、未実装 row は reserved + owning task)。
5. checker 実装 + test.sh 配線 + negative self-test。
6. queue Phase 11 追加、EQM-110 proof、pointer → EQM-111。
7. self-review、commit。

## Test path

- `./tools/test.sh` green 維持 (docs は非破壊、checker gate 追加分は green で導入)。
- `python3 tools/check_contract_coverage.py --self-test` (negative: implemented 行の file 欠落 / COMPLETE task の reserved 残留を FAIL にできること)。

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| SEM v1.1 ↔ Q01–Q26 決定 | 旧決定の黙示上書き | synthesis の決定対照表 + self-review 差分列挙 |
| coverage matrix ↔ SEM §16 | 契約 row 漏れ | checker が §16 契約 ID list と matrix row の一致を検査 |
| checker ↔ test.sh | 誤 FAIL で全 task を塞ぐ | self-test + baseline green 確認 |
| queue Phase 11 ↔ 既存 queue | 依存/形式崩れ | QUEUE_OPERATION_RULES 準拠、dependency sweep 実施 |

## Completion checklist (planned)

- [ ] synthesis / SEM v1.1 / registry / coverage / checker / queue の 7 成果物が揃う
- [ ] `./tools/test.sh` PASS (checker 含む)
- [ ] self-review 作成、commit `autopilot(EQM-110): ...`
