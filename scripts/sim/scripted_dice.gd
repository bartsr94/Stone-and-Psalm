## A `Dice` whose draws are a script you hand it, for tests that need an exactly known
## sequence. `SIMULATION_SPEC.md` §20 — the determinism suite relies on this.
##
## Only `randf()` is overridden: `Dice` derives `randf_range`, `randi_range` and `chance` from
## it, so one list of numbers in [0, 1) controls every kind of draw. `randf()` returns the next
## value, cycling back to the start once the list runs out (so a short script can drive a long
## run); `is_exhausted()` reports whether it has wrapped.
class_name ScriptedDice
extends Dice

var _values: PackedFloat32Array = PackedFloat32Array()
var _cursor: int = 0
var _wrapped: bool = false


func _init(values: Array = []) -> void:
	super._init(0)
	for value in values:
		_values.append(clampf(float(value), 0.0, 0.9999999))


func randf() -> float:
	if _values.is_empty():
		return 0.0
	if _cursor >= _values.size():
		_cursor = 0
		_wrapped = true
	var value := _values[_cursor]
	_cursor += 1
	return value


## True once the script has been consumed at least once and wrapped back to the start.
func is_exhausted() -> bool:
	return _wrapped


func serialize() -> Dictionary:
	return {"cursor": _cursor, "wrapped": _wrapped}


func deserialize(data: Dictionary) -> void:
	_cursor = int(data.get("cursor", 0))
	_wrapped = bool(data.get("wrapped", false))
