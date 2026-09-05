## `Tuning` reads the numbers, and the 3D conventions are what they are supposed to be.
##
## The convention assertions are deliberately hard-coded here rather than read from the same
## file they check: this is the lock on Architecture Guide §4, and its whole value is that it
## fails if someone changes a convention without meaning to. Changing these later means
## remaking every asset.
extends GutTest


func test_reads_a_number() -> void:
	assert_almost_eq(Tuning.get_num("camera.ortho_size_start_m"), 44.0, 0.0001)


func test_reads_a_whole_number() -> void:
	assert_eq(Tuning.get_int("world.terrain_chunk_cells"), 32)


func test_missing_path_is_loud() -> void:
	# A silent default would surface months later as a subtly wrong camera or economy.
	assert_eq(Tuning.get_num("camera.no_such_key"), 0.0, "returns zero")
	assert_push_error("Tuning: camera.no_such_key is missing or not a number")


func test_path_through_a_missing_section_is_loud() -> void:
	assert_eq(Tuning.get_num("no_such_section.at_all"), 0.0, "returns zero")
	assert_push_error("Tuning: no_such_section.at_all is missing or not a number")


func test_non_numeric_value_is_loud() -> void:
	# Every section carries a `_comment` string, so this is a reachable mistake.
	assert_eq(Tuning.get_num("camera._comment"), 0.0, "returns zero")
	assert_push_error("Tuning: camera._comment is missing or not a number")


func test_world_conventions() -> void:
	assert_almost_eq(Tuning.get_num("world.terrain_cell_m"), 2.0, 0.0001, "2 m terrain cell")
	assert_almost_eq(Tuning.get_num("world.building_snap_m"), 1.0, 0.0001, "1 m building snap")


func test_camera_conventions() -> void:
	assert_almost_eq(Tuning.get_num("camera.pitch_deg"), 40.0, 0.0001, "starts at 40 degrees")
	assert_almost_eq(Tuning.get_num("camera.pitch_min_deg"), 15.0, 0.0001, "lowest safe pitch")
	assert_almost_eq(Tuning.get_num("camera.pitch_max_deg"), 80.0, 0.0001, "highest safe pitch")
	assert_almost_eq(Tuning.get_num("camera.yaw_step_deg"), 90.0, 0.0001, "90 degree yaw steps")
	assert_almost_eq(Tuning.get_num("camera.yaw_turn_seconds"), 0.25, 0.0001, "turn over 0.25 s")
	assert_almost_eq(
		Tuning.get_num("camera.mouse_yaw_degrees_per_pixel"),
		0.25,
		0.0001,
		"middle-mouse yaw sensitivity"
	)
	assert_almost_eq(
		Tuning.get_num("camera.mouse_pitch_degrees_per_pixel"),
		0.25,
		0.0001,
		"middle-mouse pitch sensitivity"
	)
	assert_almost_eq(Tuning.get_num("camera.ortho_size_min_m"), 20.0, 0.0001, "20 m closest")
	assert_almost_eq(Tuning.get_num("camera.ortho_size_max_m"), 160.0, 0.0001, "160 m widest")


func test_starting_zoom_is_inside_the_convention_range() -> void:
	assert_between(
		Tuning.get_num("camera.ortho_size_start_m"),
		Tuning.get_num("camera.ortho_size_min_m"),
		Tuning.get_num("camera.ortho_size_max_m"),
		"the camera cannot start outside its own zoom range"
	)
