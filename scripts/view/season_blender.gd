## Resolves `data/seasons.json` into a concrete parameter set for a given day of year.
##
## A presentation helper, not a node and not authoritative: every renderer that wants the
## season (the environment driver, the terrain material, the vegetation tint) makes one of
## these and samples it on `SimClock.day_passed`. Sampling is a handful of lerps, so there is
## no need to cache or to route it through a signal from one owner.
##
## The four keyframes are anchored to the days they peak on and looped by `SeasonCurve`, so a
## day in late December blends the autumn and (mid-January) winter keyframes.
class_name SeasonBlender
extends RefCounted

const CONFIG_PATH := "res://data/seasons.json"

var _peak_days: Array = []
var _keyframes: Array = []
var _loaded := false


func _init() -> void:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("SeasonBlender: cannot open %s" % CONFIG_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary and parsed.has("keyframes")):
		push_error("SeasonBlender: %s has no keyframes" % CONFIG_PATH)
		return
	_keyframes = parsed["keyframes"]
	for keyframe in _keyframes:
		_peak_days.append(int(keyframe["peak_day"]))
	_loaded = true


func is_loaded() -> bool:
	return _loaded


func peak_days() -> Array:
	return _peak_days.duplicate()


## The resolved seasonal parameters for `day_of_year` (1–365). Scalars and colours are lerped
## between the two bracketing keyframes; `broadleaf_bare` is taken from whichever of the two is
## nearer, so the trees are bare for the winter half of the transition and in leaf for the
## spring half.
func sample(day_of_year: int) -> Dictionary:
	if not _loaded:
		return {}

	var b := SeasonCurve.blend(day_of_year, _peak_days)
	var from_key: Dictionary = _keyframes[b["from"]]
	var to_key: Dictionary = _keyframes[b["to"]]
	var t: float = b["t"]

	return {
		"season_name": from_key["name"] if t < 0.5 else to_key["name"],
		"blend": t,
		"sun_energy_scale": _lerp_num(from_key, to_key, "sun_energy_scale", t),
		"sun_tint": _lerp_col(from_key, to_key, "sun_tint", t),
		"sky_top": _lerp_col(from_key, to_key, "sky_top", t),
		"sky_horizon": _lerp_col(from_key, to_key, "sky_horizon", t),
		"ambient_energy_scale": _lerp_num(from_key, to_key, "ambient_energy_scale", t),
		"fog_density": _lerp_num(from_key, to_key, "fog_density", t),
		"fog_color": _lerp_col(from_key, to_key, "fog_color", t),
		"ground_tint": _lerp_col(from_key, to_key, "ground_tint", t),
		"water_color": _lerp_col(from_key, to_key, "water_color", t),
		"snow_coverage": _lerp_num(from_key, to_key, "snow_coverage", t),
		"broadleaf_tint": _lerp_col(from_key, to_key, "broadleaf_tint", t),
		"pine_tint": _lerp_col(from_key, to_key, "pine_tint", t),
		"broadleaf_bare": bool(from_key["broadleaf_bare"]) if t < 0.5 else bool(to_key["broadleaf_bare"]),
	}


func _lerp_num(from_key: Dictionary, to_key: Dictionary, key: String, t: float) -> float:
	return lerpf(float(from_key[key]), float(to_key[key]), t)


func _lerp_col(from_key: Dictionary, to_key: Dictionary, key: String, t: float) -> Color:
	return Color.html(str(from_key[key])).lerp(Color.html(str(to_key[key])), t)
