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
| `core` | user layer より下の基盤 infra | EQEntry, EQOrdering, EQScheduler, EQBackend, EQSortedArrayBackend, EQBinaryHeapBackend, EQSnapshot, EQTrace, EQError, EQValidation, EQVersion, EQRng, EQEffectRecord, EQEffectChunk, EQOrderExplanation |
| `L0` | turn order ("who acts next") | EQRuntime, EQActorRegistry, EQActorState, EQActionResult, EQManager, EQPrediction, EQSaveAdapter, EQNodeBridge |
| `L1` | policy selection | EQConfig, EQPolicy, EQFixedRoundPolicy, EQCTBPolicy, EQEnergyPolicy, EQWaitTurnPolicy |
| `L2` | reservation / prepared actions | EQActionDefinition, EQReservation, EQReservationRuntime, EQActionResolutionPolicy, EQCondition, EQTagMatcher, EQTriggerEngine, EQTransaction, EQTriggerIndex |
| `L3` | event-line internals | *(Phase 5+)* |
| `presentation` | simulation/presentation split (L0/L1 に漏れてはいけない) | EQPresentationEvent, EQPresentationPolicy, EQPresentationBuffer |
| `ui` | runtime/editor UI projections (L0/L1 に漏れてはいけない) | EQTimelineHud, EQDebugOverlay, EQTimelineDock, EQDebugInspector, EQTemplateGenerator |

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
