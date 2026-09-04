## The Phase 0 scene is wired the way the conventions require.
##
## This is the test that would have caught a camera left on perspective projection, a sun with
## shadows switched off, or an environment scene that silently failed to instance — none of
## which throw, and all of which are only visible in a screenshot nobody has taken yet.
extends GutTest

const MAIN_SCENE := "res://scenes/world/main.tscn"

var _scene: Node = null


func before_each() -> void:
	_scene = add_child_autofree(load(MAIN_SCENE).instantiate())


func _find(node_name: String) -> Node:
	# owned = false, because the environment's nodes belong to their own scene, not to this one.
	return _scene.find_child(node_name, true, false)


func _camera() -> Camera3D:
	return _find("Camera3D") as Camera3D


func test_scene_loads() -> void:
	assert_not_null(_scene, "main.tscn instantiates")


func test_camera_is_orthographic() -> void:
	assert_eq(
		_camera().projection, Camera3D.PROJECTION_ORTHOGONAL,
		"the projection is a convention, not a preference"
	)


func test_camera_pitch_is_forty_degrees() -> void:
	var forward: Vector3 = -_camera().global_transform.basis.z
	var pitch_degrees: float = rad_to_deg(asin(-forward.y))
	assert_almost_eq(pitch_degrees, 40.0, 0.01, "the camera looks down 40 degrees")


func test_camera_is_above_and_behind_its_focus() -> void:
	var rig: Node3D = _find("CameraRig") as Node3D
	var camera: Camera3D = _camera()
	assert_gt(
		camera.global_position.y, rig.global_position.y,
		"the camera sits above the focus point it orbits"
	)
	assert_almost_eq(
		camera.position.length(), Tuning.get_num("camera.distance_m"), 0.01,
		"and at the configured distance from it"
	)


func test_camera_starts_inside_the_zoom_range() -> void:
	assert_between(
		_camera().size,
		Tuning.get_num("camera.ortho_size_min_m"),
		Tuning.get_num("camera.ortho_size_max_m"),
		"the starting ortho size respects the clamp"
	)


func test_camera_far_plane_clears_the_scene() -> void:
	assert_gt(
		_camera().far, Tuning.get_num("camera.distance_m"),
		"a far plane inside the camera's own distance would clip everything away"
	)


func test_one_sun_casting_shadows() -> void:
	var sun: DirectionalLight3D = _find("Sun") as DirectionalLight3D
	assert_not_null(sun, "there is a directional light")
	assert_true(sun.shadow_enabled, "it casts shadows")
	assert_eq(
		sun.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
		"four cascades, per Architecture Guide 4.6"
	)
	assert_almost_eq(sun.directional_shadow_max_distance, 150.0, 0.01, "150 m shadow range")
	assert_gt(sun.rotation_degrees.x, -90.0, "the sun is above the horizon")
	assert_lt(sun.rotation_degrees.x, 0.0, "and not below it")


func test_environment_has_the_things_quality_comes_from() -> void:
	var world_env: WorldEnvironment = _find("WorldEnvironment") as WorldEnvironment
	assert_not_null(world_env, "the environment scene instanced")
	var env: Environment = world_env.environment
	assert_not_null(env, "and carries an Environment")
	assert_true(env.ssao_enabled, "SSAO on")
	assert_true(env.ssil_enabled, "SSIL on")
	assert_true(env.volumetric_fog_enabled, "volumetric fog on")
	assert_eq(env.background_mode, Environment.BG_SKY, "a sky, not a flat colour")
	assert_not_null(env.sky, "and a sky resource to draw it from")


func test_no_baked_global_illumination() -> void:
	# Architecture Guide 4.6: SDFGI is too expensive for a builder, and lightmaps are
	# incompatible with buildings appearing at runtime.
	var env: Environment = (_find("WorldEnvironment") as WorldEnvironment).environment
	assert_false(env.sdfgi_enabled, "no SDFGI")


func test_ground_and_one_greybox_building() -> void:
	var ground: MeshInstance3D = _find("Ground") as MeshInstance3D
	var building: MeshInstance3D = _find("GreyboxBuilding") as MeshInstance3D
	assert_not_null(ground, "there is a ground plane")
	assert_not_null(building, "and one greybox building on it")

	var box: BoxMesh = building.mesh as BoxMesh
	assert_almost_eq(
		building.position.y, box.size.y * 0.5, 0.0001,
		"the building sits on the ground rather than sunk into it"
	)


func test_ground_covers_the_widest_zoom() -> void:
	# Found by looking at a render: at the widest zoom the ground ran out and the camera saw
	# past the edge of the world. A 40° pitch stretches the vertical extent across the ground
	# by 1/sin(40°), which is the part that is easy to forget.
	var ground: MeshInstance3D = _find("Ground") as MeshInstance3D
	var plane: PlaneMesh = ground.mesh as PlaneMesh
	var widest: float = Tuning.get_num("camera.ortho_size_max_m")
	var pitch: float = deg_to_rad(Tuning.get_num("camera.pitch_deg"))

	var viewport_width: float = float(ProjectSettings.get_setting("display/window/size/viewport_width", 1152))
	var viewport_height: float = float(ProjectSettings.get_setting("display/window/size/viewport_height", 648))

	var needed_across: float = widest * (viewport_width / viewport_height)
	var needed_along: float = widest / sin(pitch)

	assert_gte(plane.size.x, needed_across, "ground spans the widest zoom across the screen")
	assert_gte(plane.size.y, needed_along, "and up the screen, where the pitch stretches it")


func test_ground_is_a_whole_number_of_terrain_cells() -> void:
	var ground: MeshInstance3D = _find("Ground") as MeshInstance3D
	var plane: PlaneMesh = ground.mesh as PlaneMesh
	var cell: float = Tuning.get_num("world.terrain_cell_m")
	assert_almost_eq(
		fmod(plane.size.x, cell), 0.0, 0.0001,
		"the ground divides evenly into 2 m cells"
	)
	assert_almost_eq(fmod(plane.size.y, cell), 0.0, 0.0001, "on both axes")


func test_building_is_on_whole_snap_units() -> void:
	var building: MeshInstance3D = _find("GreyboxBuilding") as MeshInstance3D
	var box: BoxMesh = building.mesh as BoxMesh
	var snap: float = Tuning.get_num("world.building_snap_m")
	assert_almost_eq(fmod(box.size.x, snap), 0.0, 0.0001, "width is a whole number of snap units")
	assert_almost_eq(fmod(box.size.z, snap), 0.0, 0.0001, "and so is depth")
