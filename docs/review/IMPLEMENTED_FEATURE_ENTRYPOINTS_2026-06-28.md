# 実装済みコードの機能単位入口一覧

作成日: 2026-06-28

根拠:

- `tests/golden/api_surface.json`: layer-aware public API surface の正本。
- `docs/design/API_SURFACE.md`: public / internal 規約と layer 割り当て。
- `addons/event_queue_manager/`: addon 本体。
- `demos/`, `dogfood/`, `test_project/tests/`, `tools/`: demo、検証、開発用入口。

public API の規約では、`class_name` を持つ file のうち、leading underscore のない `func` / `var`、uppercase `const`、`enum`、`signal` が surface です。

## 1. Addon / Plugin 入口

| 機能 | ファイル | 入口 |
|---|---|---|
| Godot plugin manifest | `addons/event_queue_manager/plugin.cfg` | name, description, author, version, script |
| EditorPlugin | `addons/event_queue_manager/plugin.gd` | `_enter_tree()` で `EQManager` custom node type を登録、`_exit_tree()` で解除 |
| scene-local manager node | `addons/event_queue_manager/runtime/eq_manager.gd` | Add Node から `EQManager` を追加、または `EQManager.new()` |

注記: editor surfaces は Control として実装されていますが、`plugin.gd` は dock/menu mounting を v1.x follow-up として扱っています。

## 2. 単純な turn-order 導線 (L0)

| 機能 | class / file | public entrypoints |
|---|---|---|
| Scene node facade | `EQManager` / `runtime/eq_manager.gd` | `configure(config)`, `set_policy(p)`, `validate()`, `register_actor(actor_id)`, `seed()`, `step()`, `advance_frame(budget, auto_result)`, `finish_action(actor_id, result)`, `is_awaiting_turn()`, `runtime()`, `set_mode(mode)`, `trace_jsonl()` |
| Manager signals | `EQManager` | `queue_changed`, `event_ready(entry)`, `turn_ready(actor_id, entry)`, `event_resolved(entry)`, `timeline_advanced(tick)`, `invalid_event_skipped(fault)` |
| Headless runtime | `EQRuntime` / `runtime/eq_runtime.gd` | `start()`, `register_actor(actor_id)`, `schedule(actor_id, due_tick, priority, kind)`, `advance()`, `finish_action(actor_id, result)`, `set_mode(m)`, `trace()`, `trace_jsonl()` |
| Runtime state | `EQRuntime` | vars: `mode`, `emit_engine_diagnostics`, `scheduler`, `registry`, `config`, `faults`, `halted`; enum: `Mode` |
| Actor registry | `EQActorRegistry` / `runtime/eq_actor_registry.gd` | `validate_register(actor_id)`, `register(actor_id)`, `is_registered(actor_id)`, `get_state(actor_id)`, `unregister(actor_id)`, `actor_ids()`, `size()` |
| Actor state | `EQActorState` / `runtime/eq_actor_state.gd` | vars: `actor_id`, `data`; methods: `bind(obj)`, `bound()`, `is_bound()`, `to_dict()`, `from_dict(d)` |
| Action close result | `EQActionResult` / `runtime/eq_action_result.gd` | vars: `cost`, `delay`, `allow_negative_cost`; method: `validate()` |
| Godot node bridge | `EQNodeBridge` / `runtime/eq_node_bridge.gd` | `bind_actor(actor_id, node)`, `node_for(actor_id)`, `on_actor_freed(actor_id)`, `prune_freed()`, `notify_reservation_resolved(reservation)`, `notify_trigger_fired(reservation)`, `notify_effect_recorded(record)`, `notify_presentation_flushed(event)` |
| Node bridge signals | `EQNodeBridge` | `turn_ready`, `reservation_resolved`, `trigger_fired`, `effect_recorded`, `presentation_flushed`, `event_invalidated` |
| Pure prediction | `EQPrediction` / `runtime/eq_prediction.gd` | `branch(runtime)`, `predict_entries(runtime, n, default_cost)`, `predict_turns(runtime, n, default_cost)` |
| Save/load wrapper | `EQSaveAdapter` / `runtime/eq_save_adapter.gd` | `save(runtime)`, `load(runtime, data)`, `contains_live_object(data)`; const: `SCHEMA_VERSION` |

## 3. Policy / Config 入口 (L1)

| 機能 | class / file | public entrypoints |
|---|---|---|
| Config resource | `EQConfig` / `resources/eq_config.gd` | vars: `policy`, `tie_break`, `schema_version`; const: `TIE_BREAKS`; method: `validate()` |
| Policy base | `EQPolicy` / `resources/policies/eq_policy.gd` | var: `policy_name`; methods: `seed(runtime, actor_ids)`, `on_turn_finished(runtime, actor_id, result)` |
| Fixed round | `EQFixedRoundPolicy` / `resources/policies/eq_fixed_round_policy.gd` | var: `initiative_key`; methods: `seed(runtime, actor_ids)`, `on_turn_finished(runtime, actor_id, result)` |
| CTB | `EQCTBPolicy` / `resources/policies/eq_ctb_policy.gd` | vars: `speed_key`, `base_cost`, `scale`; methods: `delay_of(cost, speed)`, `seed(runtime, actor_ids)`, `on_turn_finished(runtime, actor_id, result)` |
| Energy | `EQEnergyPolicy` / `resources/policies/eq_energy_policy.gd` | vars: `speed_key`, `energy_key`, `threshold`, `base_cost`; methods: `seed(runtime, actor_ids)`, `on_turn_finished(runtime, actor_id, result)` |
| Wait Turn | `EQWaitTurnPolicy` / `resources/policies/eq_wait_turn_policy.gd` | vars: `wait_key`, `agility_key`, `base_cost`; methods: `seed(runtime, actor_ids)`, `on_turn_finished(runtime, actor_id, result)` |

## 4. Reservation / Trigger / Transaction 入口 (L2)

| 機能 | class / file | public entrypoints |
|---|---|---|
| Action definition | `EQActionDefinition` / `resources/eq_action_definition.gd` | enum: `Kind`; const: `DURATION_UNLIMITED`; vars: `kind`, `delay`, `tags`, `duration`, `rumination`, `operation_target_tag`; methods: `validate()`, `to_dict()`, `from_dict(d)` |
| Reservation instance | `EQReservation` / `runtime/eq_reservation.gd` | enum: `Status`; vars: `actor_id`, `definition`, `event_id`, `remaining_duration`, `remaining_ruminations`, `status`, `target_id`; methods: `validate()`, `to_dict()`, `from_dict(d)` |
| Reservation runtime | `EQReservationRuntime` / `runtime/eq_reservation_runtime.gd` | var: `runtime`; methods: `submit(res)`, `resolve_next()`, `pending()`, `armed_for(actor_id)` |
| Action Resolution policy | `EQActionResolutionPolicy` / `resources/policies/eq_action_resolution_policy.gd` | vars: `ap_key`, `recovery_key`, `ap_max`, `recovery_per_tick`, `action_ap_cost`; methods: `seed(runtime, actor_ids)`, `on_turn_finished(runtime, actor_id, result)`, `wait_close(runtime, actor_id, result, transaction)`, `ready_reservation_for(runtime, actor_id, spent)` |
| Trigger condition | `EQCondition` / `resources/eq_condition.gd` | vars: `match_kind`, `match_source`, `match_target`, `require_tags`, `any_tags`, `sensing_required`, `custom_predicate`; method: `matches(view)` |
| Tag matching | `EQTagMatcher` / `runtime/eq_tag_matcher.gd` | `has_all(tags, required)`, `has_any(tags, candidates)` |
| Trigger engine | `EQTriggerEngine` / `runtime/eq_trigger_engine.gd` | vars: `faults`, `max_chain`; methods: `arm(reservation, condition, current_tick)`, `on_event_resolved(view, current_tick)`, `fire_cascade(initial_view, current_tick, follow_up)`, `armed_count()`, `armed_for(actor_id)` |
| Trigger index | `EQTriggerIndex` / `runtime/eq_trigger_index.gd` | `add(reservation, condition)`, `candidates(view)`, `matching_reservations(view)`, `target_bucket_size(target_id)`, `wildcard_size()`, `size()`, `clear()` |
| Transaction | `EQTransaction` / `runtime/eq_transaction.gd` | `working()`, `draft()`, `is_live_unchanged()`, `is_committed()`, `draft_push(due_tick, priority, kind, actor_id)`, `draft_cancel(event_id)`, `rollback()`, `commit()` |

## 5. Core scheduler / determinism 入口

| 機能 | class / file | public entrypoints |
|---|---|---|
| Event entry | `EQEntry` / `runtime/eq_entry.gd` | vars: `event_id`, `due_tick`, `priority`, `sequence`, `kind`, `actor_id`, `payload`, `generation`; methods: `make(...)`, `to_dict()`, `from_dict(d)` |
| Ordering comparator | `EQOrdering` / `runtime/eq_ordering.gd` | `less_than(a, b)`, `sort(entries)`, `decided_by(a, b)` |
| Scheduler | `EQScheduler` / `runtime/eq_scheduler.gd` | var: `current_tick`; methods: `push(...)`, `pop()`, `peek_next()`, `peek(n)`, `cancel(event_id)`, `reschedule(event_id, new_due_tick, new_priority)`, `size()`, `is_empty()`, `snapshot()`, `restore(data)` |
| Backend contract | `EQBackend` / `runtime/backends/eq_backend.gd` | `insert(entry)`, `pop_min()`, `peek_min()`, `ordered()`, `size()`, `is_empty()`, `clear()` |
| Sorted-array backend | `EQSortedArrayBackend` / `runtime/backends/eq_sorted_array_backend.gd` | backend contract methods |
| Binary-heap backend | `EQBinaryHeapBackend` / `runtime/backends/eq_binary_heap_backend.gd` | backend contract methods |
| Snapshot contract | `EQSnapshot` / `runtime/eq_snapshot.gd` | enum: `Load`; const: `SCHEMA_VERSION`; methods: `validate(data)`, `is_supported_version(version)`, `describe(code)`, `equals(a, b)` |
| Trace | `EQTrace` / `runtime/eq_trace.gd` | `record(fields)`, `record_resolved(entry, cause, decided_by)`, `size()`, `records()`, `to_jsonl()`, `trace_run(callable)` |
| Order explanation | `EQOrderExplanation` / `runtime/eq_order_explanation.gd` | vars: `actor_id`, `decided_by`, `factors`; consts: `FACTOR_KEYS`, `FACTOR_DIRECTION`; methods: `of(entry, predecessor)`, `deciding_factor()`, `to_dict()` |
| Deterministic RNG | `EQRng` / `runtime/eq_rng.gd` | `get_seed()`, `randi()`, `randf()`, `randi_range(from, to)`, `to_dict()`, `from_dict(d)`, `from_saved(d)` |
| Error taxonomy | `EQError` / `runtime/eq_error.gd` | enums: `Recoverability`, `Severity`; methods: `is_known(code)`, `recoverability_of(code)`, `severity_of(code)`, `surfaces_in(code)`; constants for config, actor, action, runtime, reservation, trigger, presentation errors |
| Validation object | `EQValidation` / `runtime/eq_validation.gd` | var: `issues`; methods: `add(code, message, context)`, `is_valid()`, `errors()`, `warnings()`, `codes()`, `has_code(code)` |
| Version helper | `EQVersion` / `runtime/eq_version.gd` | consts: `ADDON_VERSION`, `MIN_GODOT_MAJOR`, `MIN_GODOT_MINOR`; methods: `engine_string()`, `is_supported_engine()` |

## 6. Presentation 入口

| 機能 | class / file | public entrypoints |
|---|---|---|
| Effect record | `EQEffectRecord` / `runtime/eq_effect_record.gd` | consts: `CLASS_IMPORTANT`, `CLASS_SENSED`, `CLASS_OFFSCREEN`; vars: `kind`, `source`, `target`, `stat`, `delta`, `classification`, `tags`; methods: `to_trace_record()`, `to_dict()`, `from_dict(d)` |
| Effect chunk | `EQEffectChunk` / `runtime/eq_effect_chunk.gd` | `add(record)`, `records()`, `size()`, `is_empty()`, `is_save_allowed()`, `clear()`, `drain()` |
| Presentation event | `EQPresentationEvent` / `runtime/eq_presentation_event.gd` | vars: `actor_id`, `position`, `classification`, `tags`, `depends_on`, `changes_position_of`; methods: `bind(obj)`, `bound()`, `to_dict()`, `from_dict(d)` |
| Presentation policy | `EQPresentationPolicy` / `resources/eq_presentation_policy.gd` | vars: `immediate_classes`, `skip_classes`, `flush_on_player_turn`; method: `validate()` |
| Presentation buffer | `EQPresentationBuffer` / `runtime/eq_presentation_buffer.gd` | `enqueue(event)`, `flush()`, `flush_player_turn()`, `flushed()`, `pending()`, `clear_flushed()` |

## 7. Runtime / Editor UI 入口

| 機能 | class / file | public entrypoints |
|---|---|---|
| Runtime timeline HUD | `EQTimelineHud` / `runtime/ui/eq_timeline_hud.gd` | `set_state(order, stale)`, `bind(manager, depth)`, `refresh()`, `set_stale(stale)`, `order()`, `is_stale()`, `is_empty_state()`, `rows()` |
| Runtime debug overlay | `EQDebugOverlay` / `runtime/ui/eq_debug_overlay.gd` | `set_state(order, explanations)`, `order()`, `explanation_for(index)`, `rows()` |
| Timeline editor Control | `EQTimelineDock` / `editor/timeline_dock.gd` | const: `DEFAULT_NEXT_N`; `set_preview(config, runtime, next_n)`, `order()`, `is_empty_state()`, `is_validation_state()`, `validation_messages()`, `row_count()` |
| Order inspector Control | `EQDebugInspector` / `editor/debug_inspector.gd` | `select(entry, predecessor)`, `show_explanation(explanation)`, `clear()`, `factor_rows()`, `decided_by()`, `is_empty_state()` |
| Template generator Control | `EQTemplateGenerator` / `editor/template_generator.gd` | `generate()`, `duplicate_to_project(target_dir)`, `manifest()`, `is_sample()`, `satisfies_production_slot()` |
| UI layout snapshot collector | `editor/testing/eq_ui_layout_snapshot_collector.gd` | test harness support; scans Control tree metadata for metrics |
| UI layout metric evaluator | `editor/testing/eq_ui_layout_metric_evaluator.gd` | test harness support; evaluates P0/P1/WARN metrics |
| UI state scenario builder | `editor/testing/eq_ui_state_scenario_builder.gd` | test harness support; synthetic editor UI scenarios |
| Calibration tab | `editor/testing/eq_calibration_tab.gd` | dev-only calibration support; normal mode exposure is forbidden by UI contract |

## 8. Demo / dogfood 入口

| 機能 | ファイル | 入口 |
|---|---|---|
| CTB demo | `demos/ctb_battle/ctb_battle.gd`, `.tscn` | speed-based L0/L1 battle |
| Energy demo | `demos/energy_battle/energy_battle.gd` | energy threshold policy |
| Wait-turn tactics demo | `demos/wait_turn_tactics/wait_turn.gd`, `.tscn` | wait / agility ordering |
| Phase battle demo | `demos/phase_battle/phase_battle.gd` | fixed round / initiative band |
| Action Resolution demo | `demos/action_resolution/demo_battle.gd` | AP, reservation, trigger, presentation |
| Stack resolution demo | `demos/stack_resolution/stack_resolution.gd` | priority-based stack composition |
| Public API dogfood slice | `dogfood/action_resolution/battle.gd` | public API only vertical slice |

## 9. Test / tool 入口

| 機能 | ファイル | 入口 |
|---|---|---|
| Standard verification | `tools/test.sh` | `./tools/test.sh` |
| API surface gate | `tools/check_api_surface.py` | `python3 tools/check_api_surface.py`, `--self-test`, `--update` |
| UI static audit | `tools/ui_static_audit.py` | `python3 tools/ui_static_audit.py --enforce` |
| Godot test runner | `test_project/tests/run_all.gd` | headless Godot runner |
| UI metric runner | `test_project/tests/ui_headless/run_ui_metrics.gd` | headless Control metric evaluation |
| Golden traces | `test_project/tests/golden/*.trace.jsonl` | deterministic trace fixtures |
| API surface fixture | `tests/golden/api_surface.json` | public API golden |

## 10. 機能別の最短入口

| やりたいこと | 最短入口 |
|---|---|
| とにかく行動順を動かす | `EQManager` + `EQConfig` + concrete policy |
| scene なしで順序を検証する | `EQRuntime` |
| queue を直接操作する | `EQScheduler` |
| actor を管理する | `EQActorRegistry`, `EQActorState` |
| 次の N 件を preview する | `EQPrediction.predict_turns()` |
| policy を変える | `EQConfig.policy` に concrete `EQPolicy` subclass |
| AP / wait / ready を扱う | `EQActionResolutionPolicy` |
| 準備・反応を扱う | `EQActionDefinition`, `EQReservation`, `EQTriggerEngine` |
| action の rollback / commit を扱う | `EQTransaction` |
| save/load する | `EQScheduler.snapshot()`, `EQScheduler.restore()`, `EQSaveAdapter` |
| trace を見る | `EQTrace`, `EQManager.trace_jsonl()` |
| UI に順序を出す | `EQTimelineHud` または `EQTimelineDock` Control |
| なぜこの順序かを見る | `EQOrderExplanation`, `EQDebugInspector` |
| sample template を project asset にする | `EQTemplateGenerator.generate()` -> `duplicate_to_project()` |

