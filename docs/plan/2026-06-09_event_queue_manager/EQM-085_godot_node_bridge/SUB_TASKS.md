# EQM-085 SUB_TASKS

## Complexity

Class: C3 (orchestrator-direct — runtime/Godot 統合の要、save/load 正しさ)
Reason:
- save/load rebind (live Node を保存形式に混ぜない、actor_id で再束縛)、actor 削除の Q05 invalidation 経路、multi-domain signal bridge。
- dogfood F2 (effect/presentation signals) の follow-up を内包。autoload は opt-in (scene-local 既定, profile)。

Required artifacts: Complexity header / Task Resolution / POLICY (model + Invariant) / IMPLEMENTATION_PLAN。UX は本 SUB_TASKS の user-goal に畳む。

## User goal

game 開発者が save すると actor_id + Resources + scheduler state が保存され (live Node は混ざらない)、load 時に rebind map で actor を live node に再束縛して進行が再現する。actor を削除すると pending events は invalidation 経路で skip される。turn/reservation/trigger/effect/presentation/invalid の signal を購読できる。autoload は任意 (既定は scene-local)。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQSaveAdapter (L0) | save/load (actor_id + Resources, no live Node) + rebind | adopt | scheduler snapshot + actor states(to_dict) + schema_version。load で re-register + rebind map で bind。 |
| EQNodeBridge (Node, L0) | actor↔node 束縛 + actor 削除 + multi-domain signals | adopt | bind_actor / on_actor_freed(→unregister=invalidation) / prune_freed(WeakRef) / 6 domain signals + notify_* helpers。 |
| actor 削除 = invalidation 経路 (Q05) | 削除 actor の pending を skip | adopt | unregister → runtime shipped が invalid_event_skipped。 |
| multi-domain signal bridge | turn/reservation/trigger/effect/presentation/invalid | adopt | manager.turn_ready/invalid_event_skipped を forward + notify_* で残り domain。F2 対応。 |
| autoload installer | opt-in、scene-local 既定 | adopt | auto-install しない。bridge は scene-local Node で動作。opt-in を doc。 |
| live Node を保存形式に混ぜる | — | reject | actor_id + WeakRef のみ (Adapter 原則)。 |

## Scheduled Task Audit

新規 scheduled task なし。EQM-085 完了で Phase 8b 完了 (083/084/085)。dogfood F2 の signal wiring を本 task で提供。
