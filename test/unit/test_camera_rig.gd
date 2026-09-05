## The camera rig's pure geometry, tested without a scene tree.
##
## These are the parts that would fail silently rather than loudly: a free orbit that drifts or
## flips, a zoom that escapes its clamp, or a diagonal pan that moves faster than a cardinal one.
extends GutTest


func test_mouse_drag_rotates_freely_and_wraps_full_turns() -> void:
	assert_almost_eq(
		CameraRig.yaw_after_mouse_drag(0.0, -180.0, 0.25),
		PI / 4.0,
		0.0001,
		"180 horizontal pixels produce a smooth 45 degree turn"
	)
	assert_almost_eq(
		CameraRig.yaw_after_mouse_drag(0.0, -1440.0, 0.25),
		0.0,
		0.0001,
		"a full drag rotation wraps exactly to the start"
	)
	assert_almost_eq(
		CameraRig.yaw_after_mouse_drag(0.0, 180.0, 0.25),
		TAU - PI / 4.0,
		0.0001,
		"dragging the other way wraps below zero"
	)


func test_vertical_mouse_drag_changes_pitch_and_respects_safe_limits() -> void:
	var start := deg_to_rad(40.0)
	assert_almost_eq(
		CameraRig.pitch_after_mouse_drag(start, -80.0, 0.25, deg_to_rad(15.0), deg_to_rad(80.0)),
		deg_to_rad(20.0),
		0.0001,
		"dragging upward lowers the camera toward the horizon"
	)
	assert_almost_eq(
		CameraRig.pitch_after_mouse_drag(start, -1000.0, 0.25, deg_to_rad(15.0), deg_to_rad(80.0)),
		deg_to_rad(15.0),
		0.0001,
		"pitch stops before reaching the horizon"
	)
	assert_almost_eq(
		CameraRig.pitch_after_mouse_drag(start, 1000.0, 0.25, deg_to_rad(15.0), deg_to_rad(80.0)),
		deg_to_rad(80.0),
		0.0001,
		"pitch stops before the orbit can flip overhead"
	)
func test_ortho_size_is_clamped_to_the_convention_range() -> void:
	assert_eq(CameraRig.clamp_ortho(60.0, 20.0, 160.0), 60.0, "a size in range is untouched")
	assert_eq(CameraRig.clamp_ortho(5.0, 20.0, 160.0), 20.0, "below the close limit clamps up")
	assert_eq(CameraRig.clamp_ortho(500.0, 20.0, 160.0), 160.0, "above the wide limit clamps down")


func test_zoom_direction_and_clamping() -> void:
	assert_lt(
		CameraRig.zoomed(60.0, 1.15, 1, 20.0, 160.0), 60.0,
		"zooming in shrinks the ortho size"
	)
	assert_gt(
		CameraRig.zoomed(60.0, 1.15, -1, 20.0, 160.0), 60.0,
		"zooming out grows it"
	)
	assert_eq(
		CameraRig.zoomed(20.0, 1.15, 1, 20.0, 160.0), 20.0,
		"zooming in at the close limit stays put"
	)
	assert_eq(
		CameraRig.zoomed(160.0, 1.15, -1, 20.0, 160.0), 160.0,
		"zooming out at the wide limit stays put"
	)


func test_zoom_in_then_out_returns_to_the_same_size() -> void:
	var once: float = CameraRig.zoomed(60.0, 1.15, 1, 20.0, 160.0)
	var back: float = CameraRig.zoomed(once, 1.15, -1, 20.0, 160.0)
	assert_almost_eq(back, 60.0, 0.0001, "a notch each way is symmetric")


func test_pan_is_still_when_there_is_no_input() -> void:
	assert_eq(
		CameraRig.pan_offset(Vector2.ZERO, 0.0, 60.0, 0.8, 0.016), Vector3.ZERO,
		"no input, no movement"
	)


func test_pan_speed_scales_with_zoom() -> void:
	# Pan is expressed in screens per second, so the same input covers proportionally more
	# ground when zoomed out. 0.8 screens/sec at a 60 m ortho size over 1 s is 48 m.
	var close_pan: Vector3 = CameraRig.pan_offset(Vector2(0.0, 1.0), 0.0, 60.0, 0.8, 1.0)
	var wide_pan: Vector3 = CameraRig.pan_offset(Vector2(0.0, 1.0), 0.0, 120.0, 0.8, 1.0)
	assert_almost_eq(close_pan.length(), 48.0, 0.001, "48 m at a 60 m ortho size")
	assert_almost_eq(wide_pan.length(), 96.0, 0.001, "twice the size pans twice as far")


func test_diagonal_pan_is_not_faster_than_cardinal() -> void:
	var cardinal: Vector3 = CameraRig.pan_offset(Vector2(0.0, 1.0), 0.0, 60.0, 0.8, 1.0)
	var diagonal: Vector3 = CameraRig.pan_offset(Vector2(1.0, 1.0), 0.0, 60.0, 0.8, 1.0)
	assert_almost_eq(
		diagonal.length(), cardinal.length(), 0.001,
		"diagonal input is normalised, not compounded"
	)


func test_pan_forward_is_away_from_the_viewer_at_every_yaw() -> void:
	# "Forward" must follow the camera round, not stay pinned to world −Z.
	assert_almost_eq(
		CameraRig.pan_offset(Vector2(0.0, 1.0), 0.0, 60.0, 0.8, 1.0).z, -48.0, 0.001,
		"at yaw 0, forward is world −Z"
	)
	assert_almost_eq(
		CameraRig.pan_offset(Vector2(0.0, 1.0), PI / 2.0, 60.0, 0.8, 1.0).x, -48.0, 0.001,
		"at a quarter turn, the same input moves along −X"
	)
