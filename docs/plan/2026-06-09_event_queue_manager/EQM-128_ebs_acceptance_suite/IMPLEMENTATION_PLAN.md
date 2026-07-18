# EQM-128 IMPLEMENTATION_PLAN — Q54 確認系 acceptance 束 + authoring/manual
## Scope
SEM v1.2 §16.2 (coverage: ebs-acceptance-suite)。Q54 の R04/R06/R08/R09/R11/R12。
## 変更対象ファイル
- `dogfood/` (acceptance シナリオ) / `docs/manual/` (v1.2 章) / `test_project/tests/golden/` (確認系 golden 群) / `tests/resource/`
- coverage row flip 最終 (orchestrator)
## 実装 steps
1. R04: game-side空間事実をnormalized event tagへ投影し、`EQCondition`で選ぶreaction trigger確認test。

> 2026-07-18 correction (EQM-137 audit): 上記testはfalse predicateでもFIREを肯定する
> false-greenだった。R04 trigger proofはgame-side空間事実をnormalized event tagへ投影し、
> `EQCondition`で選ぶ厳密testへ修正。reaction definition solve/invalidationのFIRE適用は
> EQM-141で意味論・bind lifetime・snapshotをまとめて設計する。
2. R06: 相互反撃ループ golden (資源述語の閉包で停止)。
3. R08: スタック順 comparator hook 適用例。
4. R09: 公平 golden は EQM-124 で作成済み → 視界非対称の変種を追加確認。
5. R11: ready_reservation_for + invalidate→issue 同一 sweep 原子性の確認 test。
6. R12: EQM 変更不要の確認記録 (test 1 本 = 発行前修飾で足りる証明)。
7. manual: 状態代数 / 関係 / メタレベル / bundle の .tres 宣言性を日本語 mirror 含め追記。
## Test path
`./tools/test.sh`。新規 golden は各 case 明示 baseline。
