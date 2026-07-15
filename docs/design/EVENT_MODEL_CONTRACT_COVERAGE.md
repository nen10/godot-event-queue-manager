# Event Model Contract Coverage

目的: `EVENT_MODEL_SEMANTICS.md` の凍結契約ごとに { owning task, 実装 file, test } を対応させ、「宣言のみで未実装」の再発 (2026-07-02 監査で確定した v1.0 の drift) を機械検査で防ぐ。検査は `tools/check_contract_coverage.py` が行い、`./tools/test.sh` の gate である。

規則:

- `status = implemented` の行は、`implementation` / `tests` 列の**全 path が実在**しなければ FAIL。
- `status = reserved` の行は、`owning task` 列の task が**すべて** `COMPLETE` / `COMPLETE_WITH_BACKLOG` になった時点で reserved のままなら FAIL (task を閉じる前に本表を flip する)。
- 行の追加・変更は SEM の契約変更 (re-freeze 記録) と同じ commit で行う。
- path は repo root 相対。複数 path は `<br>` 区切り。

<!-- coverage-table: DO NOT reformat column order; parsed by tools/check_contract_coverage.py -->

| contract | SEM | owning task | status | implementation | tests |
|---|---|---|---|---|---|
| master-ordering (comparator / reschedule-only) | §3 | EQM-010, EQM-011 | implemented | addons/event_queue_manager/runtime/eq_ordering.gd<br>addons/event_queue_manager/runtime/eq_scheduler.gd | test_project/tests/core/test_eq_ordering.gd<br>test_project/tests/core/test_eq_scheduler.gd |
| snapshot-v1 (schema_version / stable load error) | §10 | EQM-012 | implemented | addons/event_queue_manager/runtime/eq_snapshot.gd | test_project/tests/core/test_eq_snapshot.gd |
| trace-open-schema (canonical trace / golden) | §11 | EQM-013 | implemented | addons/event_queue_manager/runtime/eq_trace.gd | test_project/tests/core/test_eq_trace_golden.gd<br>test_project/tests/core/test_eq_trace_properties.gd |
| resilience-two-mode (dev fail-fast / shipped fail-safe) | §16 | EQM-022 | implemented | addons/event_queue_manager/runtime/eq_runtime.gd | test_project/tests/core/test_eq_runtime.gd |
| actor-registry (actor_id 再利用禁止) | §13 | EQM-021 | implemented | addons/event_queue_manager/runtime/eq_actor_registry.gd | test_project/tests/resource/test_eq_actor_registry.gd |
| sim-classification (Q12 感知分類 = simulation data) | §11 | EQM-080, EQM-081 | implemented | addons/event_queue_manager/runtime/eq_effect_record.gd<br>addons/event_queue_manager/runtime/eq_presentation_buffer.gd | test_project/tests/presentation/test_eq_effect_record.gd<br>test_project/tests/presentation/test_eq_presentation_buffer.gd |
| conditions-contract (solve AND / invalidation OR / level 評価 / invalidation-wins / key 導出 / EQConditionSpec) | §5.4, §5.6 | EQM-111 | implemented | addons/event_queue_manager/resources/eq_condition_spec.gd<br>addons/event_queue_manager/runtime/eq_condition_eval.gd<br>addons/event_queue_manager/resources/eq_action_definition.gd | test_project/tests/resource/test_eq_condition_spec.gd<br>test_project/tests/trigger/test_eq_condition_eval.gd |
| named-predicate-registry (predicate 条件の serialize) | §5.5 | EQM-111 | implemented | addons/event_queue_manager/runtime/eq_runtime.gd | test_project/tests/trigger/test_eq_condition_eval.gd |
| event-line-backend (data model / watched sparse polling / event_line_progressed) | §4.3, §4.6 | EQM-112 | implemented | addons/event_queue_manager/runtime/eq_event_lines.gd | test_project/tests/core/test_eq_event_lines.gd |
| sweep-rule-registry (pattern (2) 実行) | §4.7 | EQM-112 | implemented | addons/event_queue_manager/runtime/eq_event_lines.gd | test_project/tests/core/test_eq_event_lines.gd |
| progression-budgets (Q43 数値) | §12.1 | EQM-112 | implemented | addons/event_queue_manager/runtime/eq_event_lines.gd | test_project/tests/performance/test_eq_event_line_budget.gd |
| resolution-pipeline (5-step / 宣言 linkage effect callback / chunk 配線) | §6.1 | EQM-113 | implemented | addons/event_queue_manager/runtime/eq_reservation_runtime.gd<br>addons/event_queue_manager/runtime/eq_runtime.gd | test_project/tests/core/test_eq_resolution_pipeline.gd |
| reaction-schedule (cascade bounded rounds) | §6.2 | EQM-113 | implemented | addons/event_queue_manager/runtime/eq_reservation_runtime.gd<br>addons/event_queue_manager/runtime/eq_trigger_engine.gd | test_project/tests/trigger/test_eq_reaction_pipeline.gd<br>test_project/tests/trigger/test_eq_rumination_cycle_guard.gd |
| reaction-fire-occurrence-context (独立 FIRE / cause transport / schema-v5) | §6.2, §10.3, §11 | EQM-132 | implemented | addons/event_queue_manager/runtime/eq_reaction_fire_context.gd<br>addons/event_queue_manager/runtime/eq_reservation_runtime.gd<br>addons/event_queue_manager/runtime/eq_trigger_engine.gd<br>addons/event_queue_manager/runtime/eq_save_adapter.gd | test_project/tests/trigger/test_eq_reaction_fire_context.gd |
| expiry-event + closed_by vocabulary | §6.3, §11 | EQM-113 | implemented | addons/event_queue_manager/runtime/eq_reservation_runtime.gd | test_project/tests/trigger/test_eq_reaction_pipeline.gd |
| invalidate-actor (正規離脱経路) | §13 | EQM-113 | implemented | addons/event_queue_manager/runtime/eq_runtime.gd<br>addons/event_queue_manager/runtime/eq_reservation_runtime.gd<br>addons/event_queue_manager/runtime/eq_node_bridge.gd | test_project/tests/core/test_eq_resolution_pipeline.gd |
| window-object-model (EQWindow / 暗黙 L0 window / budget / deadline 既定) | §8.1, §9 | EQM-114 | implemented | addons/event_queue_manager/runtime/eq_window.gd<br>addons/event_queue_manager/runtime/eq_reservation_runtime.gd<br>addons/event_queue_manager/runtime/eq_transaction.gd | test_project/tests/transaction/test_eq_window.gd |
| ordering-hook (order_simultaneous / golden 被覆) | §7.1 | EQM-115 | implemented | addons/event_queue_manager/runtime/eq_reservation_runtime.gd | test_project/tests/core/test_eq_order_hook.gd |
| race-pattern (race-group id / 敗者一掃 / 表示分離) | §5.2 | EQM-116 | implemented | addons/event_queue_manager/runtime/eq_reservation_runtime.gd<br>addons/event_queue_manager/runtime/ui/eq_debug_overlay.gd | test_project/tests/trigger/test_eq_race_pattern.gd |
| snapshot-v2 + save-enforcement (is_save_allowed 配線 / migrator) | §10 | EQM-117 | implemented | addons/event_queue_manager/runtime/eq_save_adapter.gd<br>addons/event_queue_manager/runtime/eq_reservation_runtime.gd | test_project/tests/transaction/test_eq_snapshot_v2.gd |
| reducibility-product-proof (EQM-053 の product model 再証明) | §16.1 | EQM-118 | implemented | addons/event_queue_manager/runtime/eq_reservation_runtime.gd | test_project/tests/policy/test_eq_reducibility_product.gd<br>test_project/tests/golden/reducibility_ctb_pipeline.trace.jsonl |
| authoring-acceptance (反撃準備 .tres 受け入れ基準) | §5.6 | EQM-119 | implemented | dogfood/action_resolution/counterattack_preparation.tres<br>dogfood/action_resolution/battle.gd | test_project/tests/resource/test_eq_authoring_acceptance.gd<br>test_project/tests/golden/authoring_counterattack.trace.jsonl |
| state-algebra (inv ペア / 共存規則 / wrapping — 標準 2 種の意味論は EQM-129) | §5.7 | EQM-121, EQM-129 | implemented | addons/event_queue_manager/runtime/eq_state_algebra.gd | test_project/tests/core/test_eq_state_algebra.gd<br>test_project/tests/core/test_eq_wrapper_semantics.gd<br>test_project/tests/golden/lifetime_composition.trace.jsonl<br>test_project/tests/golden/wrapper_chains.trace.jsonl |
| rate-modifier-stack (suspension / 加算 + override) | §4.8 | EQM-121 | implemented | addons/event_queue_manager/runtime/eq_event_lines.gd | test_project/tests/core/test_eq_event_lines.gd |
| relation-graph (型宣言 / 維持 sweep / 直列縫合 / 離脱連動) | §13.1 | EQM-122 | implemented | addons/event_queue_manager/runtime/eq_relation_graph.gd<br>addons/event_queue_manager/runtime/eq_reservation_runtime.gd | test_project/tests/core/test_eq_relation_graph.gd |
| expansion-transform (target 展開 / パターン変換 / 多重適用) | §6.4 | EQM-123 | implemented | addons/event_queue_manager/runtime/eq_reservation_runtime.gd | test_project/tests/core/test_eq_resolution_rewrites.gd |
| provenance-chain (発行連鎖 / 段ごとメタレベル) | §6.5 | EQM-123 | implemented | addons/event_queue_manager/runtime/eq_reservation_runtime.gd | test_project/tests/core/test_eq_resolution_rewrites.gd |
| atomic-bundle (member 一括 → 単一 sweep) | §7.2 | EQM-124 | implemented | addons/event_queue_manager/runtime/eq_reservation_runtime.gd | test_project/tests/core/test_eq_atomic_bundle.gd<br>test_project/tests/golden/fairness_bundle.trace.jsonl |
| meta-level-premature-close (単一 int / 同値 = 介入成功 / cause: intervention) | §8.2, §8.3 | EQM-125 | implemented | addons/event_queue_manager/runtime/eq_window.gd<br>addons/event_queue_manager/runtime/eq_reservation_runtime.gd | test_project/tests/transaction/test_eq_premature_close.gd<br>test_project/tests/golden/interception_close.trace.jsonl |
| phase-recursion (sub-checkpoint / ループ巻き戻し + 入力解除) | §8.4 | EQM-126 | implemented | addons/event_queue_manager/runtime/eq_window.gd<br>addons/event_queue_manager/runtime/eq_reservation_runtime.gd | test_project/tests/transaction/test_eq_phase_rollback.gd<br>test_project/tests/golden/mirror_loop_rollback.trace.jsonl |
| snapshot-v3 (modifier / relation / provenance / checkpoint tables) | §10.1 | EQM-127 | implemented | addons/event_queue_manager/runtime/eq_save_adapter.gd<br>addons/event_queue_manager/runtime/eq_reservation_runtime.gd | test_project/tests/transaction/test_eq_snapshot_v3.gd |
| ebs-acceptance-suite (Q54 確認系 golden 束 + authoring 追加) | §16.2 | EQM-128 | implemented | test_project/tests/core/test_eq_ebs_acceptance.gd<br>docs/ja/manual/reservations.md | test_project/tests/core/test_eq_ebs_acceptance.gd<br>test_project/tests/golden/mutual_counter_stop.trace.jsonl |

## Deferred (coverage 対象外, 記録のみ)

- composite atomic bundle (§7.1 staging 後段) — **v1.2 で deferral 解除** (Q49、EBS 公平/波及の同時性が実需要): reserved 行 atomic-bundle (EQM-124) へ移行。
- grouped・micro-event-line (Q24) / replay 製品化 (Q15) / effect grouping (Q35 follow-up — **EQM-119 で再評価し defer 確定**: `EQEffectRecord.tags` + classification で grouping 表現が既に可能、実需要の信号が出るまで専用 field は追加しない)。
- v1.2 で新たに defer: rate modifier の乗算 (整数分数 + 丸め規則の定義が前提)、結び直し語彙の追加パターン、変換のパラメータ型追加 — いずれも需要確定時に additive (Q23 ガードレール)。
