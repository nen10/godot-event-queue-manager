# EQM-060 IMPLEMENTATION_PLAN — Contract (design pinned by orchestrator; implementation delegated to Codex 5.5)

## Scope

ADD two addon files + tests. Do NOT touch `tools/`, golden files, the queue, or any existing class. The orchestrator wires the API surface (LAYER_MAP / API_SURFACE.md / golden) after delivery.

- `addons/event_queue_manager/resources/eq_condition.gd` — `EQCondition` (Resource).
- `addons/event_queue_manager/runtime/eq_tag_matcher.gd` — `EQTagMatcher` (RefCounted, static helpers).
- `test_project/tests/trigger/test_eq_condition.gd`, `test_project/tests/trigger/test_eq_tag_matcher.gd` (new dir `tests/trigger/`).

## Pinned design — EQTagMatcher (runtime/eq_tag_matcher.gd)

`class_name EQTagMatcher extends RefCounted`. Static, pure, deterministic:

- `static func has_all(tags: Array, required: Array) -> bool` — true iff every element of `required` is in `tags` (empty `required` → true).
- `static func has_any(tags: Array, candidates: Array) -> bool` — true iff at least one element of `candidates` is in `tags` (empty `candidates` → true; this is the "no constraint" identity).

## Pinned design — EQCondition (resources/eq_condition.gd)

`class_name EQCondition extends Resource`. Matches a normalized **event view** Dictionary against criteria. An unset/empty criterion is a wildcard (no constraint). All set criteria must hold (AND).

Exports (serializable):
- `@export var match_kind: StringName = &""` — if non-empty, the view's `kind` must equal it.
- `@export var match_source: StringName = &""` — if non-empty, the view's `source` must equal it.
- `@export var match_target: StringName = &""` — if non-empty, the view's `target` must equal it.
- `@export var require_tags: Array[StringName] = []` — all must be present in the view's `tags` (via `EQTagMatcher.has_all`).
- `@export var any_tags: Array[StringName] = []` — if non-empty, at least one must be present (via `EQTagMatcher.has_any`).
- `@export var sensing_required: bool = false` — **placeholder** for the range/sensing adapter (Q12 / spatial). Not evaluated yet; reserved so a later sensing adapter plugs in. Document it as a placeholder.

Transient (NOT serialized — set in code, like a weak binding):
- `var custom_predicate: Callable = Callable()` — if valid (`custom_predicate.is_valid()`), it is called as `custom_predicate.call(view)` and must return true for a match.

Method:
- `func matches(view: Dictionary) -> bool` — returns true iff ALL of: kind (if set), source (if set), target (if set), `has_all(view.tags, require_tags)`, `has_any(view.tags, any_tags)`, and (if `custom_predicate.is_valid()`) `custom_predicate.call(view) == true`. `sensing_required` is NOT evaluated (placeholder). Read view fields defensively: `view.get("kind", &"")`, `view.get("source", &"")`, `view.get("target", &"")`, `view.get("tags", [])`.

The **event view** is `{ "kind": StringName, "source": StringName, "target": StringName, "tags": Array[StringName] }`. (EQM-061's trigger engine builds this from a resolving event/reservation; this task only defines matching against the view.)

## Tests (test_project/tests/trigger/)

Follow suite conventions: `extends RefCounted`; `static func run(t) -> void:`; `t.ok` / `t.eq`; `preload("res://addons/...")`. CRITICAL: never use `:=` on an untyped right-hand side (e.g. an element of an untyped Array) — use `var x: Type = ...`.

- `test_eq_tag_matcher.gd`: has_all (all present / one missing / empty required→true), has_any (one present / none present / empty candidates→true).
- `test_eq_condition.gd`: a view matches when criteria are met; mismatches on kind, on source, on target, on a missing required tag, and (with any_tags set) when none of any_tags present; a wildcard condition (all unset) matches anything; require_tags + any_tags combined; a custom_predicate that returns false blocks a match and one that returns true allows it; sensing_required does not affect matching (placeholder).

## Gate (orchestrator owns)

- Codex: ensure the Godot run reports `[run_all] ... failures=0`. The api-surface check WILL report the two new classes as a surface change — that is EXPECTED; do NOT run `--update-golden` and do NOT edit `tools/check_api_surface.py`. The orchestrator wires LAYER_MAP (EQCondition: L2, EQTagMatcher: L2), API_SURFACE.md, and re-baselines the golden, then runs `./tools/test.sh` for the final green.

## Completion checklist

- [ ] EQTagMatcher.has_all / has_any.
- [ ] EQCondition matches() across kind/source/target/require_tags/any_tags/custom_predicate; sensing_required placeholder unevaluated; wildcard matches all.
- [ ] tests under tests/trigger/ cover the above.
- [ ] (orchestrator) LAYER_MAP + API_SURFACE + golden wired; `./tools/test.sh` PASS, api-surface ok, no L3 leak.
