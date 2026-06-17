# EQM-060 SUB_TASKS

## Complexity

Class: C2 (delegated implementation; contract pinned by orchestrator)
Reason:
- condition/tag matching の contract。EQM-061 (reaction engine)/062 が乗る。
- contract (EQCondition の形 + matching 意味論) は **orchestrator が完全に固定** → 実装+tests は忠実実行 (設計縮小リスク低)。

Required artifacts: Complexity header / Task Resolution / Contract (IMPLEMENTATION_PLAN) / 委譲記録。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQCondition (Resource, L2) | event を criteria で match | adopt | match_kind/source/target + require_tags(AND)/any_tags(OR) + transient custom predicate + sensing placeholder。 |
| EQTagMatcher (runtime, L2) | tag-set matching helper | adopt | has_all / has_any (static)。EQCondition が利用。 |
| event view = 正規化 Dictionary | EQEntry/EQReservation 双方を match | adopt | {kind, source, target, tags}。trigger engine (EQM-061) が build。 |
| custom predicate = transient Callable | serializable core を壊さない | adopt | .tres に保存しない (weak binding と同様)。 |
| range/sensing | adapter placeholder のみ | adopt | acceptance: placeholder。実装は後続/adapter。 |
| 委譲: Codex (gpt-5.5) | 忠実実装 + tests | adopt | contract 固定済み。orchestrator が gate + api-surface 配線。 |

## 委譲 (P2)

- executor: Codex 5.5 (gpt-5.5 xhigh)。contract = `IMPLEMENTATION_PLAN.md`。
- scope: `addons/.../resources/eq_condition.gd`, `addons/.../runtime/eq_tag_matcher.gd`, `test_project/tests/trigger/*`。**tools/check_api_surface.py と golden は触らない** (orchestrator が配線)。
- gate: orchestrator が LAYER_MAP/API_SURFACE 追記 + `--update` golden + `./tools/test.sh`。repair 上限 3。

## Scheduled Task Audit

新規 scheduled task なし。次の依存解放は EQM-061 (reaction preparation runtime)。
