# EQM-130 IMPLEMENTATION_PLAN — 維持条件 sweep 自動駆動 + 公平合成 + 迎撃標準形 [repair: A2/C1/C2]
## Scope
相談4「EQM は評価タイミングのみ固定する」の実装追付け + acceptance 補強 2 件。
## 変更対象
- `runtime/eq_reservation_runtime.gd` (step_tick / run_sweep_rules 後の自動 run_maintenance)
- `runtime/eq_runtime.gd` (named predicate registry の callables 供給 accessor)
- `tests/core/test_eq_relation_graph.gd` (自動駆動 test 追加) + 公平合成 golden + 迎撃標準形 test
## 要点
- 既定 sweep (eqm.sweep.primary_threshold) = step_tick で自動評価。カスタム sweep 名 = 同名 sweep rule (§4.7) 実行直後に自動評価。predicates は runtime named registry から自動供給。relations 未接続 = no-op。
- 公平: 公平関係 → 展開 → 非対称反射の合成 golden (fairness_relation_chain)。
- 迎撃標準形: effect handler 内から intervene_close を呼ぶ例示 test。
