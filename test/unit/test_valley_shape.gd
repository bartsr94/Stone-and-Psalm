## The valley profile is deliberately pure, so its boundary conditions can be locked down
## without loading a scene or generating the whole terrain grid.
extends GutTest


func test_meander_is_zero_when_no_wavelength_exists() -> void:
	assert_eq(ValleyShape.meander_offset(10, 14.0, 0.0), 0.0, "invalid wavelength is stable")


func test_meander_reaches_zero_at_a_full_wavelength() -> void:
	assert_almost_eq(
		ValleyShape.meander_offset(0, 14.0, 140.0), 0.0, 0.0001, "starts at the centre"
	)
	assert_almost_eq(
		ValleyShape.meander_offset(140, 14.0, 140.0), 0.0, 0.0001,
		"returns to the centre after one wavelength"
	)


func test_downstream_fall_is_clamped_to_the_dale() -> void:
	assert_eq(ValleyShape.downstream_fall(0, 192, 5.0), 0.0, "head of the dale")
	assert_almost_eq(ValleyShape.downstream_fall(191, 192, 5.0), 5.0, 0.0001, "mouth of the dale")
	assert_almost_eq(ValleyShape.downstream_fall(300, 192, 5.0), 5.0, 0.0001, "past the mouth")


func test_cross_section_has_a_flat_floor_and_smooth_moor_transition() -> void:
	assert_eq(
		ValleyShape.cross_section_rise(30.0, 30.0, 66.0, 36.0, 22.0, 7.0),
		0.0,
		"the precinct floor is flat"
	)
	assert_almost_eq(
		ValleyShape.cross_section_rise(66.0, 30.0, 66.0, 36.0, 22.0, 7.0),
		36.0,
		0.0001,
		"the slope reaches its authored rise"
	)
	assert_almost_eq(
		ValleyShape.cross_section_rise(88.0, 30.0, 66.0, 36.0, 22.0, 7.0),
		43.0,
		0.0001,
		"the moor ramp reaches the full side height"
	)


func test_river_depth_is_full_in_the_channel_and_zero_at_the_bank() -> void:
	assert_eq(ValleyShape.river_depth(3.0, 3.0, 1.8, 3.0), 1.8, "channel bed is full depth")
	assert_almost_eq(ValleyShape.river_depth(6.0, 3.0, 1.8, 3.0), 0.0, 0.0001, "bank joins the floor")
	assert_eq(ValleyShape.river_depth(10.0, 3.0, 1.8, 3.0), 0.0, "outside the bank")


func test_terrain_bands_are_ordered_from_floor_to_moor() -> void:
	assert_eq(
		ValleyShape.terrain_for_distance(30.0, 30.0, 66.0),
		TerrainTypes.Terrain.MEADOW,
		"floor is meadow"
	)
	assert_eq(
		ValleyShape.terrain_for_distance(40.0, 30.0, 66.0),
		TerrainTypes.Terrain.WOODLAND,
		"side is woodland"
	)
	assert_eq(
		ValleyShape.terrain_for_distance(66.0, 30.0, 66.0),
		TerrainTypes.Terrain.MOOR,
		"upper side is moor"
	)


func test_noise_amplitude_is_low_on_the_floor_and_high_on_the_moor() -> void:
	assert_eq(
		ValleyShape.noise_amplitude(30.0, 30.0, 66.0, 0.3, 5.5, 4.0),
		0.3,
		"the building floor stays nearly flat"
	)
	assert_almost_eq(
		ValleyShape.noise_amplitude(66.0, 30.0, 66.0, 0.3, 5.5, 4.0),
		4.0,
		0.0001,
		"the moor uses its authored amplitude"
	)
