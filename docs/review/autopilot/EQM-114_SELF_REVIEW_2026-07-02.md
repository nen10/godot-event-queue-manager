# EQM-114 Self-Review 2026-07-02

Pattern: P0 (orchestrator-direct)。Repair: 2/3 — (1) test の型推論 (untyped draft からの `:=`)、(2) deadline window で clock 込み snapshot 比較が commit を誤って conflict 化 → `is_live_unchanged_ignoring_clock()` + commit 後の live clock 保存で修正 (製品挙動の修正)。

## Execution summary

SEM v1.1 §8.1/§9 の window object model を実装した。`EQWindow` {window_id, owner, nest_level, kind, deadline, budget_paid, draft} を first-class 化し、EQReservationRuntime が LIFO stack (暗黙 root = L0 await 境界, nest 0, trace なし) を所有。EQTransaction は window の draft 実装として従属 (単体 API は互換併存)。meta-cost budget は owner state から支払い・chain 中非回復 (Q02)・絶対 max depth backstop。deadline (絶対 tick) は pop 後 / tick 境界の定義点で検査され、既定 = draft rollback + close (`window_closed cause: deadline`)、`pre_close` hook でのみ明示 commit (Q37)。`is_save_boundary()` (chunk 空 ∧ 明示 window なし) を EQM-117 の配線用に提供。

## Acceptance result — met

queue row 全項目充足。特筆: 「時間切れの強制 default 行動」は存在しない (hook の明示 commit のみ — silent fallback 禁止)。demo golden 不変 (暗黙 root を trace しない設計判断、SUB_TASKS G)。

## Design decisions (deviations from the sketch)

- **deadline を scheduler event にしない**: expiry (Q40) と違い、deadline event の pop は live scheduler を変えるため、EQTransaction の snapshot-commit と本質的に衝突する (commit が pop 済み event を復活させる)。Q37 は event 化を要求していないため、決定的な定義点検査 (resolve_next pop 後 + step_tick) を採った。POLICY.md 記録済み。
- **commit 競合 guard**: commit は「clock を除き live 不変」のときのみ (WINDOW_COMMIT_CONFLICT で拒否 + rollback)。deadline window で tick が流れても、entry/counter が不変なら commit 可能で、live clock は commit を跨いで保存される。draft-log replay 型 commit は将来課題 (POLICY fallback 表)。

## Test summary

```text
./tools/test.sh -> RESULT: PASS; files=55 checks=876 failures=0
[api-surface] ok / [contract-coverage] violations=0 (flip 後 implemented=16)
```

既存 transaction tests (EQM-070/071/072) は無変更 green — EQTransaction 従属化の互換を証明。

## Golden updates (explicit)

`tests/golden/api_surface.json` のみ (+EQWindow L2 ほか上記)。demo/dogfood trace golden 不変。

## No sample-only completion / UX path reduction

合成シナリオの property 検証 (非回復残高・厳密 deadline tick・conflict 時の rollback)。silent default 行動という hack 経路を仕様として封じた。

## Repair-now / follow-up

なし。次: EQM-115 (ordering hook) READY。
