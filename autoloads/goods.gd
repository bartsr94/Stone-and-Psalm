## Reads `data/goods.json` and hands out good definitions. `SIMULATION_SPEC.md` §8.
##
## Pure lookup, exactly like `Tuning` but keyed by good id rather than a dotted path — there is
## no per-run state to save. Loaded in `_init` for the same reason `Tuning` is: other autoloads'
## `_ready` must be able to depend on it regardless of autoload declaration order.
extends Node

const GOODS_PATH := "res://data/goods.json"

var _defs: Dictionary = {}   ## good_id -> Dictionary


func _init() -> void:
	var file := FileAccess.open(GOODS_PATH, FileAccess.READ)
	if file == null:
		push_error("Goods: cannot open %s" % GOODS_PATH)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("Goods: %s is not a JSON object" % GOODS_PATH)
		return

	for key in parsed.keys():
		if key == "_comment":
			continue
		_defs[key] = parsed[key]


func exists(good_id: String) -> bool:
	return _defs.has(good_id)


## All good ids, sorted — the order a UI or a determinism-sensitive iteration should use.
func all_ids() -> Array:
	var ids := _defs.keys()
	ids.sort()
	return ids


func get_def(good_id: String) -> Dictionary:
	if not _defs.has(good_id):
		push_error("Goods: unknown good %s" % good_id)
		return {}
	return _defs[good_id]


func label(good_id: String) -> String:
	return str(get_def(good_id).get("name", good_id))


func category(good_id: String) -> String:
	return str(get_def(good_id).get("category", ""))


func weight_per_unit(good_id: String) -> float:
	return float(get_def(good_id).get("weight_per_unit", 1.0))


func spoilage_pct_per_day(good_id: String) -> float:
	return float(get_def(good_id).get("spoilage_pct_per_day", 0.0))


func base_price(good_id: String) -> float:
	return float(get_def(good_id).get("base_price", 0.0))


## The building type ids whose local inventory can hold this good (`storable_in` in the data).
func storable_in(good_id: String) -> Array:
	return get_def(good_id).get("storable_in", []).duplicate()


func can_be_stored_in(good_id: String, building_type_id: String) -> bool:
	return storable_in(good_id).has(building_type_id)
