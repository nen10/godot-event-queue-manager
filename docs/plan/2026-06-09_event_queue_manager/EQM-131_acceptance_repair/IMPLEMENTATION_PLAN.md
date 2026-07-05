# EQM-131 IMPLEMENTATION_PLAN — acceptance 修理 [repair: B1/B2 + EBS A-R08-1]
## Scope
R06 停止根拠の是正 / retarget 中間段 / R08 の EBS 注釈整合。
## 変更対象
- `runtime/eq_reservation_runtime.gd` (retarget params.stage の int index 対応のみ)
- `tests/core/test_eq_ebs_acceptance.gd` (R06 変種 + assert 実質化 + R08 書き換え) + `tests/golden/focus_cost_counter_stop.trace.jsonl` (new)
## 要点
- R06: 焦点 counter line を反撃 effect で decrement、`<= 0` の LINE_THRESHOLD invalidation で停止 — 「コスト述語の閉包」の証明。既存 mutual_counter_stop golden は回数系変種として存置。常真 assert を実質化。
- retarget: stage に int (provenance index、reach 検査つき) を additive 追加。"root"/"direct" は不変。
- R08: メタレベル昇順・同率付与順 (EBS META_LEVEL_ASSIGNMENT A-R08-1) の hook 例へ書き換え。
