## The work-block calculator: given everything the day is already spoken for — the offices, the
## chapter, the Masses, meals, lectio, sleep — what discrete spans are left for manual labour?
## `SIMULATION_SPEC.md` §6.1. Work blocks are **spans, not a budget**: a 90-minute task cannot
## be done in a 40-minute block, and that fragmentation is the winter penalty.
##
## Pure interval maths. `Liturgy.day_plan` assembles the busy intervals from the calendar data
## and the solar model, then calls in here; nothing in this file knows what an office is.
##
## Intervals are `[start_minute, end_minute]` arrays of floats, minute-of-day. They may overlap
## and arrive unsorted.
class_name Horarium
extends RefCounted


## The free spans inside `[window_start, window_end]` once every busy interval is removed.
## Spans shorter than `min_span` minutes are dropped — they are not usable labour.
static func free_spans(
	busy: Array, window_start: float, window_end: float, min_span: float = 5.0
) -> Array:
	var merged := merge(busy)
	var spans: Array = []
	var cursor := window_start
	for interval in merged:
		var b_start: float = maxf(float(interval[0]), window_start)
		var b_end: float = minf(float(interval[1]), window_end)
		if b_end <= window_start or b_start >= window_end:
			continue
		if b_start - cursor >= min_span:
			spans.append([cursor, b_start])
		cursor = maxf(cursor, b_end)
	if window_end - cursor >= min_span:
		spans.append([cursor, window_end])
	return spans


## Sorts and unions a set of intervals. Zero- and negative-length intervals are discarded.
static func merge(intervals: Array) -> Array:
	var sorted: Array = []
	for interval in intervals:
		if float(interval[1]) > float(interval[0]):
			sorted.append([float(interval[0]), float(interval[1])])
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])

	var out: Array = []
	for interval in sorted:
		if out.is_empty() or interval[0] > out[-1][1]:
			out.append([interval[0], interval[1]])
		else:
			out[-1][1] = maxf(out[-1][1], interval[1])
	return out


## Total minutes across a list of spans.
static func total_minutes(spans: Array) -> float:
	var total := 0.0
	for span in spans:
		total += float(span[1]) - float(span[0])
	return total


## Of the span time, how much falls within `[daylight_start, daylight_end]` — the labour that
## can actually be done outdoors. This is the figure that collapses in winter.
static func daylight_minutes(spans: Array, daylight_start: float, daylight_end: float) -> float:
	var total := 0.0
	for span in spans:
		total += maxf(0.0, minf(float(span[1]), daylight_end) - maxf(float(span[0]), daylight_start))
	return total


## The single longest span, in minutes — the biggest uninterrupted task a person could take on.
static func longest_span(spans: Array) -> float:
	var longest := 0.0
	for span in spans:
		longest = maxf(longest, float(span[1]) - float(span[0]))
	return longest
