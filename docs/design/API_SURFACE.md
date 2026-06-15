# API Surface (v1)

status: authoritative for v1 (EQM-023, 2026-06-15). The public API surface, tagged by layer, gated by `tools/check_api_surface.py` against `tests/golden/api_surface.json`.

---

## 1. Public / internal convention

- **public** member: a `func` or `var` whose name has **no leading underscore**. `const` members are public when `UPPER_CASE`. `enum` / `signal` are public.
- **internal** member: a leading underscore (`_handle_fault`, `_binding`, `_META`). Not part of the surface; may change freely.
- Only files with a `class_name` contribute to the surface.
- Annotations are part of the public form: `@abstract func` and `@export var` are extracted; a signature change (param/return/var type) is a surface diff.

## 2. Layers (roadmap §3.1)

The user-facing surface is layered so a simple-path user never meets deep machinery. **An L3 symbol must not appear in an L0/L1 public signature** — the gate fails on such a leak.

| layer | meaning | classes |
|---|---|---|
| `core` | foundational infra below the user layers | EQEntry, EQOrdering, EQScheduler, EQBackend, EQSortedArrayBackend, EQSnapshot, EQTrace, EQError, EQValidation, EQVersion |
| `L0` | turn order ("who acts next") | EQRuntime, EQActorRegistry, EQActorState, EQActionResult, EQManager, EQPrediction |
| `L1` | policy selection | EQConfig, EQPolicy, EQFixedRoundPolicy, EQCTBPolicy, EQEnergyPolicy |
| `L2` | reservation / prepared actions | *(Phase 5: EQM-050+)* |
| `L3` | event-line internals | *(Phase 5+)* |

A public class absent from the layer map (`LAYER_MAP` in `tools/check_api_surface.py`) fails the gate: every public class must be assigned exactly one layer. Update this table and `LAYER_MAP` together.

## 3. The gate

`./tools/test.sh` runs `python3 tools/check_api_surface.py` (and `--self-test`). It fails when:

1. the extracted surface differs from `tests/golden/api_surface.json` (any undocumented API change);
2. a public class has no layer assigned;
3. an L3 class name appears in an L0/L1 public signature (layer leak).

`--self-test` verifies the leak detector on synthetic data every run, so the leak gate cannot silently rot before L2/L3 classes exist.

## 4. Updating the golden (explicit approval)

A surface change is deliberate. To re-baseline:

```sh
python3 tools/check_api_surface.py --update      # or: ./tools/test.sh --update-golden api_surface
```

Then record the diff and reason in the task's self-review. Never update on a normal run (mirrors DETERMINISM_TRACE_TEST_POLICY §2).

## 5. References

- Layering rationale: `ROADMAP.md` §3.1, `EVENT_MODEL_SEMANTICS.md` §2.2
- Determinism / golden approval: `docs/devflow/policy/DETERMINISM_TRACE_TEST_POLICY.md`
