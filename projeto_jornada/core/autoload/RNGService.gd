extends Node

var _rng := RandomNumberGenerator.new()
var current_seed: int = 1

func start(seed_value: int) -> void:
    current_seed = seed_value
    _rng.seed = seed_value

func next_float() -> float:
    return _rng.randf()

func range_int(min_value: int, max_value: int) -> int:
    return _rng.randi_range(min_value, max_value)

func weighted_index(weights: Array) -> int:
    var total := 0.0
    for w in weights:
        total += maxf(float(w), 0.0)
    if total <= 0.0:
        return -1
    var roll := next_float() * total
    var acc := 0.0
    for i in range(weights.size()):
        acc += maxf(float(weights[i]), 0.0)
        if roll <= acc:
            return i
    return weights.size() - 1

func snapshot() -> Dictionary:
    return {"seed": current_seed, "state": _rng.state}

func restore(data: Dictionary) -> void:
    current_seed = int(data.get("seed", 1))
    _rng.seed = current_seed
    if data.has("state"):
        _rng.state = int(data.state)
