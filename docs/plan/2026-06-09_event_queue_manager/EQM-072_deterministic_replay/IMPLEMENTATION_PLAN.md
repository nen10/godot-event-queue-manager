# EQM-072 IMPLEMENTATION_PLAN — Contract (design pinned; implementation delegated to Codex 5.5)

## Scope (tests + one runtime file)

ADD `addons/event_queue_manager/runtime/eq_rng.gd` and `test_project/tests/transaction/test_eq_rng_replay.gd`. Do NOT touch `tools/`, golden files, the queue, or `runtime/eq_snapshot.gd` (EQRng self-serializes; the scheduler snapshot already exists). The orchestrator wires the API surface (LAYER_MAP / golden) after delivery.

## Pinned design — EQRng (runtime/eq_rng.gd)

`class_name EQRng extends RefCounted`. A deterministic, seedable, serializable RNG wrapping Godot's `RandomNumberGenerator` (which exposes `seed` and `state`).

- `func _init(p_seed: int = 0) -> void` — create the inner RandomNumberGenerator and set its `seed = p_seed`.
- `func get_seed() -> int` — the seed.
- `func randi() -> int` / `func randi_range(from: int, to: int) -> int` / `func randf() -> float` — delegate to the inner RNG.
- `func to_dict() -> Dictionary` — `{ "seed": <inner.seed>, "state": <inner.state> }` (captures the exact stream position).
- `func from_dict(d: Dictionary) -> void` — restore: set inner `seed = int(d["seed"])` FIRST, then `state = int(d["state"])` (order matters — setting seed resets state, so state must be applied last to restore the exact position).
- `static func from_saved(d: Dictionary) -> EQRng` — convenience: make one and `from_dict(d)`.

Determinism contract: two EQRng with the same seed produce identical streams; `to_dict` then `from_dict` into another EQRng continues the identical stream.

## Tests (test_project/tests/transaction/test_eq_rng_replay.gd)

Suite conventions: `extends RefCounted`; `static func run(t) -> void:`; `t.ok`/`t.eq`; `preload("res://addons/...")`. CRITICAL: never use `:=` on an untyped right-hand side (e.g. an element of an untyped Array) — use `var x: Type = ...`.

1. **same-seed determinism**: two `EQRng.new(12345)` produce the same sequence of `randi()` (e.g. first 10 equal).
2. **save/restore continues the stream**: from one rng, pull some values, `to_dict()`, pull a tail A; restore a second rng `from_dict(saved)`, pull the same count → tail B; assert A == B.
3. **random-dependent ORDER reproduced via snapshot**: build a scheduler scenario whose event order depends on the rng — e.g. for N actors, draw a random `due_tick` (randi_range) per scheduled event from the rng and push to an `EQScheduler` (res://addons/event_queue_manager/runtime/eq_scheduler.gd). Resolve K events to get order A (uninterrupted). Repeat the SAME run but midway save both the scheduler snapshot (`scheduler.snapshot()`) and `rng.to_dict()`, restore into a fresh scheduler+rng, and continue; the full resolved order must equal A, byte-for-byte / id-for-id. This proves snapshot restore reproduces random-dependent order/results under the same seed.

## Gate (orchestrator owns)

- Codex: ensure `[run_all] ... failures=0`. The api-surface check WILL report `EQRng` as a new class — EXPECTED; do NOT run `--update-golden`, do NOT edit `tools/check_api_surface.py`. The orchestrator wires `EQRng: core` and re-baselines the golden, then runs `./tools/test.sh` for the final green. If test.sh hits a sandbox log-path crash, use `HOME="$PWD/.godot_user/home" ./tools/test.sh`.

## Completion checklist

- [ ] EQRng: seed/randi/randi_range/randf/to_dict/from_dict/from_saved; from_dict sets seed then state.
- [ ] same-seed determinism; save/restore continues stream; random-dependent scheduler order reproduced via snapshot+rng restore.
- [ ] (orchestrator) LAYER_MAP (EQRng: core) + golden wired; `./tools/test.sh` PASS, api-surface ok.
