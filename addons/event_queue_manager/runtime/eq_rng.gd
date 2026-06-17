class_name EQRng
extends RefCounted
## Deterministic, seedable, serializable RNG wrapping Godot's
## RandomNumberGenerator. to_dict captures (seed, state) — the exact stream
## position — so a snapshot/restore reproduces random-dependent order and results
## under the same seed (deterministic replay). from_dict applies seed first, then
## state, because setting the seed resets the state.

var _inner: RandomNumberGenerator


func _init(p_seed: int = 0) -> void:
	_inner = RandomNumberGenerator.new()
	_inner.seed = p_seed


func get_seed() -> int:
	return _inner.seed


func randi() -> int:
	return _inner.randi()


func randi_range(from: int, to: int) -> int:
	return _inner.randi_range(from, to)


func randf() -> float:
	return _inner.randf()


func to_dict() -> Dictionary:
	return {
		"seed": _inner.seed,
		"state": _inner.state,
	}


func from_dict(d: Dictionary) -> void:
	_inner.seed = int(d["seed"])
	_inner.state = int(d["state"])


static func from_saved(d: Dictionary) -> EQRng:
	var rng := EQRng.new()
	rng.from_dict(d)
	return rng
