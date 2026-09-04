## Circular interpolation across four seasonal keyframes anchored to days of the year.
##
## Pure static maths. The season blender (`scripts/view/season_blender.gd`) holds the actual
## colours and densities; this only answers "which two keyframes bracket this day, and how far
## between them are we" — with the year treated as a loop, so late December blends forward into
## the winter keyframe that peaks in mid-January.
##
## Keyframe peak days must be given in ascending order. The segment that wraps the year end
## (autumn's peak → winter's peak) is handled by adding a year to the far anchor.
class_name SeasonCurve
extends RefCounted

const _DAYS_PER_YEAR := 365


## Returns `{from: int, to: int, t: float}` — the indices of the two bracketing keyframes and
## the 0…1 blend factor between them for `day_of_year` (1–365). `peak_days` is an array of the
## four keyframes' peak days, ascending.
static func blend(day_of_year: int, peak_days: Array) -> Dictionary:
	var count := peak_days.size()
	if count == 0:
		return {"from": 0, "to": 0, "t": 0.0}
	if count == 1:
		return {"from": 0, "to": 0, "t": 0.0}

	var day := wrapi(day_of_year, 1, _DAYS_PER_YEAR + 1)

	for i in count:
		var start_day := int(peak_days[i])
		var end_index := (i + 1) % count
		var end_day := int(peak_days[end_index])
		# The last segment wraps the year: its end anchor is a year later.
		if end_index == 0:
			end_day += _DAYS_PER_YEAR

		var probe := day
		# Before the first peak, the day belongs to the wrapping segment a year earlier.
		if i == count - 1 and day < start_day:
			probe += _DAYS_PER_YEAR

		if probe >= start_day and probe < end_day:
			var span := float(end_day - start_day)
			var t := 0.0 if span <= 0.0 else float(probe - start_day) / span
			return {"from": i, "to": end_index, "t": clampf(t, 0.0, 1.0)}

	# Days on or before the first peak sit at the very end of the wrapping segment.
	return {"from": count - 1, "to": 0, "t": 1.0}


## Linear-interpolates one scalar per keyframe for `day_of_year`.
static func lerp_scalar(day_of_year: int, peak_days: Array, values: Array) -> float:
	var b := blend(day_of_year, peak_days)
	var from_index: int = b["from"]
	var to_index: int = b["to"]
	var t: float = b["t"]
	return lerpf(float(values[from_index]), float(values[to_index]), t)


## Linear-interpolates one colour per keyframe for `day_of_year`.
static func lerp_color(day_of_year: int, peak_days: Array, colors: Array) -> Color:
	var b := blend(day_of_year, peak_days)
	var from_index: int = b["from"]
	var to_index: int = b["to"]
	var t: float = b["t"]
	return (colors[from_index] as Color).lerp(colors[to_index] as Color, t)
