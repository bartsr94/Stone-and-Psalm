## A seeded random stream, injected wherever the simulation needs chance.
##
## `SIMULATION_SPEC.md` §10 and Architecture Guide §7: sim code never calls the global
## `randf()`. Each system that needs randomness is handed its own `Dice` at construction, so a
## run is reproducible from a seed and a test can hand it a `ScriptedDice` instead and get an
## exactly known sequence.
##
## The generator's `state` advances with every draw; `serialize`/`deserialize` capture it so a
## save resumes the stream mid-sequence rather than restarting it.
class_name Dice
extends RefCounted

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value


## A float in [0, 1). Every other draw is derived from this one, so a subclass (`ScriptedDice`)
## only has to override this method to control the whole stream.
##
## The derived methods below call `self.randf()`, not a bare `randf()`: GDScript's global
## `randf()` built-in would otherwise shadow the method and the override would never be seen.
func randf() -> float:
	return _rng.randf()


## A float in [minimum, maximum).
func randf_range(minimum: float, maximum: float) -> float:
	return minimum + self.randf() * (maximum - minimum)


## An integer in [minimum, maximum], both ends included.
func randi_range(minimum: int, maximum: int) -> int:
	return minimum + int(self.randf() * float(maximum - minimum + 1))


## True with probability `probability` (clamped to [0, 1]).
func chance(probability: float) -> bool:
	return self.randf() < clampf(probability, 0.0, 1.0)


## One element of `options`, uniformly. Returns null for an empty array.
func pick(options: Array) -> Variant:
	if options.is_empty():
		return null
	return options[randi_range(0, options.size() - 1)]


## The seed and stream position. Stored as strings: the generator state is a 64-bit value, and
## JSON numbers are doubles — round-tripping it as a number would silently lose the low bits and
## break determinism after a load.
func serialize() -> Dictionary:
	return {"seed": str(_rng.seed), "state": str(_rng.state)}


func deserialize(data: Dictionary) -> void:
	_rng.seed = int(str(data.get("seed", "0")))
	_rng.state = int(str(data.get("state", str(_rng.state))))
