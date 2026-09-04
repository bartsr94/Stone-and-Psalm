## The pure work-block maths: subtracting busy intervals from a window and measuring what's left.
extends GutTest


func test_free_spans_are_the_gaps_between_busy_intervals() -> void:
	var busy := [[100.0, 160.0], [300.0, 330.0]]
	var spans := Horarium.free_spans(busy, 0.0, 400.0)
	assert_eq(spans, [[0.0, 100.0], [160.0, 300.0], [330.0, 400.0]])


func test_overlapping_and_unsorted_busy_intervals_are_merged() -> void:
	var busy := [[300.0, 330.0], [90.0, 160.0], [140.0, 200.0]]
	var spans := Horarium.free_spans(busy, 0.0, 400.0)
	assert_eq(spans, [[0.0, 90.0], [200.0, 300.0], [330.0, 400.0]])


func test_busy_intervals_outside_the_window_are_ignored() -> void:
	var busy := [[-50.0, 20.0], [500.0, 600.0]]
	var spans := Horarium.free_spans(busy, 0.0, 400.0)
	assert_eq(spans, [[20.0, 400.0]])


func test_short_gaps_are_dropped() -> void:
	var busy := [[100.0, 160.0], [166.0, 300.0]]
	var spans := Horarium.free_spans(busy, 0.0, 400.0, 10.0)
	assert_eq(spans, [[0.0, 100.0], [300.0, 400.0]], "the 6-minute gap is not usable labour")


func test_total_and_daylight_minutes() -> void:
	var spans := [[0.0, 100.0], [200.0, 260.0]]
	assert_almost_eq(Horarium.total_minutes(spans), 160.0, 0.001)
	assert_almost_eq(Horarium.daylight_minutes(spans, 50.0, 230.0), 50.0 + 30.0, 0.001,
		"only the part of each span inside [50, 230] counts")


func test_longest_span() -> void:
	assert_almost_eq(Horarium.longest_span([[0.0, 40.0], [100.0, 190.0], [300.0, 305.0]]), 90.0, 0.001)


func test_a_fully_booked_window_has_no_free_time() -> void:
	assert_eq(Horarium.free_spans([[0.0, 400.0]], 0.0, 400.0), [])
