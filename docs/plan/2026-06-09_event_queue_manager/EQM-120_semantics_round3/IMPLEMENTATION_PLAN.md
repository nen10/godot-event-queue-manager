# EQM-120 IMPLEMENTATION_PLAN — semantics round 3

## Scope

EBS 拡張ラウンド Q44–Q54 の決定 (相談ラウンド2・3, 2026-07-05) の確定記述 (SEM v1.2 / registry finalization / synthesis) + coverage reserved 行 + queue Phase 12 (EQM-121..128) 起票 + EBS 引き渡し原本の同期。製品 runtime code の変更はしない。

## 変更対象ファイル

- `docs/design/EVENT_MODEL_SEMANTICS.md` — v1.2 additive 改訂 (§4.8/§5.7/§6.4–6.5/§7.2/§8.2–8.4/§10.1/§11/§13.1/§16.2/§17)
- `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` — Q44–Q54 finalization (status 表 / user意見 / 相談ラウンド3 表 / pointer 表)
- `docs/review/EVENT_MODEL_OPEN_QUESTIONS_SYNTHESIS_2026-07-05.md` — 新規 (決定根拠)
- `docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md` — reserved 10 行 + Deferred 節更新
- `docs/plan/2026-06-09_event_queue_manager/IMPLEMENTATION_QUEUE.md` — Phase 12 追加 + proof + pointer
- (EBS repo) `docs/design/EQM_EXTENSION_REQUEST.md` — 相談ラウンド3 記録の同期

## 実装 steps

1. task packet (UX/POLICY/SUB_TASKS/本 file)。
2. synthesis 記録 (決定対照 + 推奨からの逸脱 4 点の明示)。
3. SEM v1.2 改訂 (additive; 各節に v1.2 マーク)。
4. registry finalization。
5. coverage reserved 行 (owning task は同 commit の queue Phase 12 に実在させる — checker の typo guard 対応)。
6. queue Phase 12 追加、EQM-120 proof、pointer 更新 (実装 run は承認待ち checkpoint)。
7. EBS 原本同期、self-review、`./tools/test.sh`、commit `autopilot(EQM-120): ...`。

## Test path

- `./tools/test.sh` green 維持 (docs/queue のみ; coverage checker は reserved 行 + queue task 実在で green のはず)。
- `python3 tools/check_contract_coverage.py` 単体でも確認 (reserved 行の owning task 実在検査)。

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| SEM v1.2 ↔ Q01–Q43 決定 | 旧決定の黙示上書き | synthesis 対照表 + self-review 差分列挙 |
| coverage 行 ↔ queue Phase 12 | owning task typo で checker FAIL | 同 commit 追加 + test.sh 実行 |
| 展開停止 = メタ/コスト ↔ §8 budget | 語彙の二重定義 | §6.4 が §8 を参照 (新語彙を作らない) |
| EBS 原本 ↔ EQM 受領コピー | drift | 受領コピーは凍結 (受領時点逐語)、以後の記録は原本側のみ更新と明記 |

## Completion checklist (planned)

- [ ] SEM v1.2 / registry / synthesis / coverage / queue / EBS 同期 の 6 成果物が揃う
- [ ] `./tools/test.sh` PASS
- [ ] self-review 作成、commit `autopilot(EQM-120): ...`
