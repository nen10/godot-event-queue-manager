# API Surface (v1)

原文: `docs/design/API_SURFACE.md`

status: v1 の正本文書 (EQM-023, 2026-06-15)。public API surface を layer ごとにタグ付けし、`tools/check_api_surface.py` が `tests/golden/api_surface.json` に対して gate します。

---

## 1. public / internal の規約

- **public** member: 名前が **leading underscore を持たない** `func` または `var`。`const` member は `UPPER_CASE` の場合 public。`enum` / `signal` は public。
- **internal** member: leading underscore を持つもの (`_handle_fault`, `_binding`, `_META`)。surface には含めず、自由に変更できます。
- `class_name` を持つ file だけが surface に寄与します。
- annotation は public form の一部です。`@abstract func` と `@export var` は抽出対象です。signature change (param / return / var type) は surface diff になります。

## 2. Layers (roadmap §3.1)

user-facing surface は layer 化されており、simple-path user が深い machinery に触れないようにします。**L3 symbol は L0/L1 public signature に現れてはいけません**。漏れた場合、gate は失敗します。

| layer | 意味 | classes |
|---|---|---|
| `core` | user layer より下の基盤 infra | EQEntry, EQOrdering, EQScheduler, EQBackend, EQSortedArrayBackend, EQBinaryHeapBackend, EQSnapshot, EQTrace, EQError, EQValidation, EQVersion, EQRng, EQEffectRecord, EQEffectChunk, EQEffectCommitResult, EQOrderExplanation |
| `L0` | turn order ("who acts next") | EQRuntime, EQActorRegistry, EQActorState, EQActionResult, EQManager, EQPrediction, EQSaveAdapter, EQNodeBridge |
| `L1` | policy selection | EQConfig, EQPolicy, EQFixedRoundPolicy, EQCTBPolicy, EQEnergyPolicy, EQWaitTurnPolicy |
| `L2` | reservation / prepared actions | EQActionDefinition, EQReservation, EQReservationRuntime, EQActionResolutionPolicy, EQCondition, EQTagMatcher, EQTriggerEngine, EQTransaction, EQTriggerIndex, EQReactionFireContext |
| `L3` | event-line internals | *(Phase 5+)* |
| `presentation` | simulation/presentation split (L0/L1 に漏れてはいけない) | EQPresentationEvent, EQPresentationPolicy, EQPresentationBuffer |
| `ui` | runtime/editor UI projections (L0/L1 に漏れてはいけない) | EQTimelineHud, EQDebugOverlay, EQTimelineDock, EQDebugInspector, EQTemplateGenerator |

transactional effect-result v1 の公開面として、core value `EQEffectCommitResult` に `make_success(records, event_views)` / `make_failure(diagnostic)`、`validate()`、read-only projection を追加します。`EQRuntime.register_effect_commit(name, handler, result_version=1)` が型付き handler を登録し、既存 `register_effect` は Array 互換経路のままです。`effect_commit_result_version(name)` で両者を識別でき、`EQReservationRuntime.last_effect_commit_outcome()` は直近の単一予約 attempt の deep-copy value snapshot を返します。`EQReservation.effect_commit_result_version` / `expiry_effect_commit_result_version` はinstance bindingで、初回submit前は-1、その後は0 legacy / 1 typedに固定します。save-bundle schema v4がserializeされる全reservationへの両fieldを導入し、v4+ writerは保持します。readerはv1-v3で欠けたfieldだけをlegacy 0へmigrateし、v1-v3に明示されたnonzero bindingを拒否します。v4+ payloadでどちらかが欠ける場合もstate適用前に拒否します。型付き v1 は bundle / expiry context では拒否されます (`EVENT_MODEL_SEMANTICS.md` §6.1、§10.2)。

EQM-132 reaction occurrence 公開面: `EQReactionFireContext` がversion 1のJSON-safe原因値を検証・複製し、`EQTriggerEngine.on_event_resolved_occurrences()` が1始まりのfire indexを公開します。従来のreservation配列projectionは維持します。`EQReservationRuntime.reaction_fire_context_for_event(event_id)`はpending FIREの独立copyを返し、同じ値がeffect handler・save・traceへ渡ります。save-bundle schema v5はscheduled rowのfieldを必須とし、historical pending FIREの原因を推測しません (`EVENT_MODEL_SEMANTICS.md` §6.2、§10.3)。

EQM-133 reaction-expiry checkpoint公開面: save-bundle schema v6はarmed membershipから独立したevent-id keyed value table `reaction_expiries`を追加します。`EQReservationRuntime.ScheduledEventOutcome`と`resolve_one_scheduled_event()`は、exactなscheduler pop 1件を`{advanced, event_id, event_kind, outcome, reservation}`として公開します。expiryを観測しても次のreservationを同じcallで消費しません。既存`resolve_next()`の挙動は維持します (`EVENT_MODEL_SEMANTICS.md` §6.3、§10.4)。

EQM-135 reservation介入公開面: `EQReservationRuntime.intervene_reservation(event_id, intervener)`は通常のscheduled PREPARED singleton 1件を対象にします。予約metaはaccepted submit時に固定し、save-bundle schema v7の`issued_meta_level`で保存します。同値以上でeffect未実行のまま無効化し、不足時は対象を維持、group／context非対応対象はfail-closedです (`EVENT_MODEL_SEMANTICS.md` §8.3.1、§10.5)。

EQM-141 reaction gate公開面: `EQTriggerEngine.preview_event_resolved_occurrences()`は期限切れcandidateも閉じずにfilterする非mutationのopaque tokenを返し、`commit_occurrence()`／`invalidate_occurrence()`はcurrent tokenだけを一度受理します。`armed_entries()`は`{reservation, condition, owner, armed_at, duration, authored_ruminations, remaining_ruminations, slot_id}`を公開し、`slot_id`はそのarm中に安定するexactなengine slot identity、3つのlifecycle値はarm-time／continuation snapshotです。既存`on_event_resolved_occurrences()`はstandalone expiryを適用して全候補commitする互換wrapperです。save schema v8はarm-bound solve/invalidationとgenerated-counter provenanceを保存します。`EQError.CONDITION_COUNTER_SOLVE_UNSUPPORTED`がCOUNTERのinvalidation-only authoring ruleを明示します。

ownership境界: 上記mutation methodはstandalone `EQTriggerEngine`向けです。
`EQReservationRuntime.engine`として得たinstanceはconsumerに対してinspection-onlyで、
commit／invalidate／disarmはruntime pipelineへ任せます。gate、declared counter、watch、
expiry ownershipを同一transactionで更新するためです。

EQM-127のhistorical schema note: save-bundle schema_version 3でoptionalな`EQReservationRuntime.state_algebra`接続とadditiveな`relations` / `state_algebra` tableを導入しました。current schema v8もこれらを変更せず保持します (`EVENT_MODEL_SEMANTICS.md` §10.1)。

layer map に存在しない public class (`tools/check_api_surface.py` の `LAYER_MAP`) は gate を失敗させます。すべての public class はちょうど 1 つの layer に割り当てられている必要があります。この表と `LAYER_MAP` は一緒に更新してください。

## 3. gate

`./tools/test.sh` は `python3 tools/check_api_surface.py` と `--self-test` を実行します。次の場合に失敗します。

1. 抽出された surface が `tests/golden/api_surface.json` と異なる (document されていない API change)。
2. public class に layer が割り当てられていない。
3. L3 class name が L0/L1 public signature に現れる (layer leak)。

`--self-test` は毎回 synthetic data で leak detector を検証します。これにより、L2/L3 class が存在する前に leak gate が静かに劣化することを防ぎます。

## 4. golden の更新 (明示承認)

surface change は deliberate な変更です。re-baseline は次で行います。

```sh
python3 tools/check_api_surface.py --update      # または: ./tools/test.sh --update-golden api_surface
```

その後、diff と理由を task の self-review に記録してください。通常実行で更新してはいけません (DETERMINISM_TRACE_TEST_POLICY §2 と同じ考え方)。

## 5. References

- Layering rationale: `ROADMAP.md` §3.1, `EVENT_MODEL_SEMANTICS.md` §2.2
- Determinism / golden approval: `docs/devflow/policy/DETERMINISM_TRACE_TEST_POLICY.md`
