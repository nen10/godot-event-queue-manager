# Error Contract (v1)

原文: `docs/design/ERROR_CONTRACT.md`

status: v1 の正本文書 (EQM-020, 2026-06-15)。validation と runtime resilience modes (EQM-022) の土台になる error taxonomy です。

Upstream: `docs/devflow/policy/RUNTIME_RESILIENCE_POLICY.md` (dev/shipped two modes)。Code home: `addons/event_queue_manager/runtime/eq_error.gd` (`EQError`)。Result type: `EQValidation`。

---

## 1. 原則

- **Stable, namespaced codes.** 各 error は `StringName` code `eqm.<area>.<name>` を持ちます。code は **append-only** です。削除も再利用もしません。code は version をまたいで有効であり、canonical trace 上で byte-safe です。
- **Recoverability over ad-hoc handling.** すべての code は下記 4 つの recoverability class のいずれかに map されます。dev / shipped behavior を決めるのは call site ではなく、この class です。
- **Report, then act.** `EQValidation` は issues の list を *report* するだけです。それに対して act するのは resilience mode toggle (EQM-022) です。dev は assert/stop、shipped は class に応じて degrade します。validation 自体は crash も skip もしません。
- **No silent swallow.** どの mode でも anomaly は stopped (dev) されるか、logged + trace-recorded (shipped) されます。黙って無視してはいけません (RUNTIME_RESILIENCE_POLICY §2)。

## 2. Recoverability classes (RUNTIME_RESILIENCE_POLICY §1 の mirror)

| class | examples | dev (fail-fast) | shipped (fail-safe) |
|---|---|---|---|
| `CONTRACT_VIOLATION` | dead-actor reservation, unknown schema_version, raw base policy | assert / stop | skip event + `invalid_event_skipped` trace + log |
| `BUDGET_EXCEEDED` | reentrancy depth (Q02 backstop), reaction-chain limit (EQM-062) | assert / stop | truncate chain + stable error event + log |
| `RESOURCE_INVALID` | missing policy, ambiguous tie-break | assert / stop | degrade to empty/unset state + log |
| `EXTERNAL_STATE` | actor node freed, WeakRef expired | warn + skip | skip + log (Q05 invalidation path) |

determinism は両 mode で維持されます。skip/degrade は trace に現れ、同じ input で再現されます (RUNTIME_RESILIENCE_POLICY §2)。normal path の結果は mode-invariant です。

## 3. Severity と surfacing

- **Severity**: `WARNING` (invalidate しない) / `ERROR` (invalidate する)。`EQValidation.is_valid()` は ERROR issue が存在しない場合だけ true です。
- **Surfacing**: `{editor, game}` の subset。issue を表示すべき場所を表します。config-validation code は両方に出ます。editor-only authoring hint は `editor` のみに出ます。Editor surfaces (EQM-090+) は `EQValidation` を projection として描画し、message を再導出しません。

## 4. Codes (v1)

| code | recoverability | severity | surfaces | meaning |
|---|---|---|---|---|
| `eqm.config.policy_missing` | RESOURCE_INVALID | ERROR | editor, game | `EQConfig.policy` が null |
| `eqm.config.policy_base_instance` | CONTRACT_VIOLATION | ERROR | editor, game | policy が raw `EQPolicy` base instance (concrete subclass が必要) |
| `eqm.config.tie_break_ambiguous` | RESOURCE_INVALID | ERROR | editor, game | `tie_break` が unset (deterministic total tie-break が選ばれていない) |
| `eqm.config.tie_break_unknown` | CONTRACT_VIOLATION | ERROR | editor, game | `tie_break` が認識されない rule を指している |
| `eqm.policy.name_empty` | RESOURCE_INVALID | WARNING | editor | `policy_name` が empty (authoring hint) |
| `eqm.actor.duplicate_id` | CONTRACT_VIOLATION | ERROR | editor, game | すでに active な actor_id を register しようとした |
| `eqm.actor.id_reused` | CONTRACT_VIOLATION | ERROR | editor, game | retired actor_id の再登録 (reuse forbidden, §13) |
| `eqm.actor.empty_id` | RESOURCE_INVALID | ERROR | editor, game | empty actor_id を register しようとした |
| `eqm.action.negative_delay` | CONTRACT_VIOLATION | ERROR | editor, game | `EQActionResult.delay < 0` (過去へ schedule してしまう) |
| `eqm.action.negative_cost` | RESOURCE_INVALID | ERROR | editor, game | `allow_negative_cost` なしで `EQActionResult.cost < 0` (§12 policy-declared) |
| `eqm.runtime.unregistered_actor_event` | CONTRACT_VIOLATION | ERROR | editor, game | removed actor の event を advance しようとした (dev は halt、shipped は skip + `invalid_event_skipped`) |
| `eqm.runtime.schedule_unregistered_actor` | CONTRACT_VIOLATION | ERROR | editor, game | unregistered actor に対する schedule / finish_action |
| `eqm.reservation.negative_delay` | CONTRACT_VIOLATION | ERROR | editor, game | `EQActionDefinition.delay < 0` |
| `eqm.reservation.immediate_nonzero_delay` | RESOURCE_INVALID | ERROR | editor, game | IMMEDIATE kind に non-zero delay がある |
| `eqm.reservation.prepared_zero_delay` | RESOURCE_INVALID | ERROR | editor, game | PREPARED kind で delay <= 0 |
| `eqm.reservation.negative_rumination` | RESOURCE_INVALID | ERROR | editor, game | `rumination < 0` |
| `eqm.reservation.invalid_duration` | RESOURCE_INVALID | ERROR | editor, game | `duration < -1` (-1 = unlimited) |
| `eqm.reservation.reaction_needs_duration` | RESOURCE_INVALID | ERROR | editor, game | duration 0 の REACTION_PREPARATION |
| `eqm.reservation.operation_needs_target` | RESOURCE_INVALID | ERROR | editor, game | OPERATION のdefinitionで`operation_target_tag`がempty、またはsubmit時のreservation `target_id`がempty |
| `eqm.reservation.missing_definition` | RESOURCE_INVALID | ERROR | editor, game | `EQReservation` に definition がない |
| `eqm.trigger.chain_limit` | BUDGET_EXCEEDED | ERROR | editor, game | trigger cascade が `EQTriggerEngine.max_chain` を超えた (chain は truncate され、record される) |
| `eqm.effect.commit_result_invalid` | CONTRACT_VIOLATION | ERROR | editor, game | `register_effect_commit` で登録した handler が `EQEffectCommitResult` 以外、または records / event views / diagnostic の value validation に失敗する result を返した |
| `eqm.effect.commit_result_version_unsupported` | CONTRACT_VIOLATION | ERROR | editor, game | transactional effect-result の登録／返却にruntime非対応versionを使用した、schema v4 reservationで必須bindingが欠けた (`reason: missing_binding`)、またはschema v1-v3がnonzero bindingを持った (`reason: binding_not_supported_by_schema`)。loadはstate適用前に拒否する |
| `eqm.effect.commit_result_context_unsupported` | CONTRACT_VIOLATION | ERROR | editor, game | rollback を保証できない atomic bundle または expiry-effect context で transactional effect-result v1 を宣言・検出した |
| `eqm.effect.commit_result_binding_mismatch` | CONTRACT_VIOLATION | ERROR | editor, game | 発行済み／load対象reservationが固定したmain／expiry handler mode（0 legacy / 1 typed）と現在のnamed-effect registryが不一致。置換後handlerは呼び出さない |

code は後続 task (snapshot / actor / reservation / trigger) でも同じ rules の下で追加されます。snapshot load codes (EQM-012 `EQSnapshot.Load`) はこの taxonomy より前に存在しており、現時点では独自 enum のままです。EQM-022 で rename なしに取り込む可能性があります。

## 5. 使い方

```gdscript
var v := config.validate()          # -> EQValidation, side effects なし
if not v.is_valid():
    for issue in v.errors():
        # issue: { code, severity, recoverability, message, context }
        ...
```

- unknown code を `EQValidation.add` に渡した場合は、最も厳しい classification (CONTRACT_VIOLATION / ERROR / surfaces everywhere) が default になります。unclassified anomaly は静かに downgrade されません。
- Stability promise: code の削除や再利用は breaking change です。pre-1.0 stance は `PROJECT_PROFILE.md` に従い `defer` です。

## 6. References

- Resilience modes: `docs/devflow/policy/RUNTIME_RESILIENCE_POLICY.md`
- Input narrowing (missing/base/ambiguous を明示 error にする理由): `docs/devflow/policy/UX_PATH_REDUCTION_POLICY.md`
- Semantics (numeric domain, over-cap): `docs/design/EVENT_MODEL_SEMANTICS.md` §12
