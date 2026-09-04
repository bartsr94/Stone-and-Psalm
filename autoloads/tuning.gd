## Reads `data/tuning.json` and hands out its numbers.
##
## Every balance constant and every fixed 3D convention lives in that file rather than in code
## (Architecture Guide §6). Values are addressed by dotted path — `Tuning.get_num("camera.pitch_deg")`.
##
## Loaded in `_init` rather than `_ready` so that autoloads declared after this one can read
## tuning values from their own `_ready` without depending on autoload ordering.
##
## A missing or non-numeric path is a programmer error, not a runtime condition: it pushes an
## error and returns zero rather than substituting a plausible default. A silent default here
## would surface as a subtly wrong camera or a subtly wrong economy months later, instead of as
## a failure at the point of the typo.
extends Node

const TUNING_PATH := "res://data/tuning.json"

var _values: Dictionary = {}


func _init() -> void:
	var file := FileAccess.open(TUNING_PATH, FileAccess.READ)
	if file == null:
		push_error("Tuning: cannot open %s" % TUNING_PATH)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_values = parsed
	else:
		push_error("Tuning: %s is not a JSON object" % TUNING_PATH)


## Returns the number at `path`, or 0.0 with a pushed error if it is missing or not a number.
func get_num(path: String) -> float:
	var value: Variant = _resolve(path)
	if value is float or value is int:
		return float(value)
	push_error("Tuning: %s is missing or not a number" % path)
	return 0.0


## Returns the whole number at `path`, or 0 with a pushed error if it is missing or not a number.
func get_int(path: String) -> int:
	var value: Variant = _resolve(path)
	if value is int:
		return value
	if value is float:
		return int(value)
	push_error("Tuning: %s is missing or not a number" % path)
	return 0


func _resolve(path: String) -> Variant:
	var node: Variant = _values
	for key in path.split("."):
		if not (node is Dictionary and node.has(key)):
			return null
		node = node[key]
	return node
