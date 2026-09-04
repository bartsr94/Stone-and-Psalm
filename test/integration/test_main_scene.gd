## The Phase 1 scene is wired the way the conventions require.
##
## This is the test that would catch a camera left on perspective projection, a terrain renderer
## missing from the scene, or an environment that silently failed to instance — none of which
## throw, and all of which are only visible in a screenshot nobody has taken yet.
extends GutTest

const MAIN_SCENE := "res://scenes/world/main.tscn"

var _scene: Node = null


func before_each() -> void:
	# Terrain is an autoload and the renderer consumes its dirty queue. Rebuild it so every
	# integration test receives the same freshly generated scene rather than depending on test
	# ordering.
	Terrain.build_preset("founding_valley")
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
	assert_almost_eq(sun.directional_shadow_max_distance, 400.0, 0.01, "400 m shadow range")
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


func test_terrain_renderer_has_all_chunks() -> void:
	var renderer: Node3D = _find("TerrainRenderer") as Node3D
	assert_not_null(renderer, "the Phase 1 terrain renderer is instanced")
	var chunk_count: int = 0
	for child in renderer.get_children():
		if not child.name.begins_with("Chunk_"):
			continue
		chunk_count += 1
		var chunk := child as MeshInstance3D
		assert_not_null(chunk, "every terrain chunk is a mesh instance")
		assert_not_null(chunk.mesh, "every terrain chunk has a generated mesh")
		assert_eq(chunk.mesh.get_surface_count(), 1, "every chunk has one surface")
	assert_eq(chunk_count, 36, "192 cells produce 6 by 6 32-cell chunks")


func test_terrain_renderer_uses_the_shared_material() -> void:
	var renderer: Node3D = _find("TerrainRenderer") as Node3D
	var first_chunk := renderer.find_child("Chunk_0_0", true, false) as MeshInstance3D
	assert_eq(
		(first_chunk.material_override as Material).resource_path,
		"res://assets/materials/m_stone_and_psalm.tres",
		"terrain uses the shared vertex-colour material"
	)


func test_terrain_renderer_has_a_derived_river_surface() -> void:
	var river: MeshInstance3D = _find("RiverSurface") as MeshInstance3D
	assert_not_null(river, "the river surface is derived from water cells")
	assert_not_null(river.mesh, "the river surface has a generated mesh")
	assert_eq(river.mesh.get_surface_count(), 1, "the river is one batched surface")
	assert_eq(
		(river.material_override as Material).resource_path,
		"res://assets/materials/m_river_water.tres",
		"the river uses its flowing water material"
	)


func test_vegetation_renderer_has_batched_categories() -> void:
	var renderer: Node3D = _find("VegetationRenderer") as Node3D
	assert_not_null(renderer, "the vegetation renderer is instanced")
	# Trees, Scrub and Rocks are always populated in the founding valley; Pines share the
	# tree placement set split by elevation, so the batch exists but may be empty.
	for category in ["Trees", "Pines", "Scrub", "Rocks"]:
		var instances: MultiMeshInstance3D = renderer.find_child(category, true, false) as MultiMeshInstance3D
		assert_not_null(instances, "%s MultiMesh exists" % category)
		assert_not_null(instances.multimesh, "%s has a MultiMesh" % category)
		assert_not_null(instances.multimesh.mesh, "%s has a prop mesh" % category)
		assert_eq(
			(instances.material_override as Material).resource_path,
			"res://assets/materials/m_stone_and_psalm.tres",
			"%s uses the shared material" % category
		)
	for populated in ["Trees", "Scrub", "Rocks"]:
		var instances: MultiMeshInstance3D = renderer.find_child(populated, true, false) as MultiMeshInstance3D
		assert_gt(instances.multimesh.instance_count, 0, "%s has visible instances" % populated)


func test_terrain_dimensions_match_the_founding_preset() -> void:
	assert_eq(Terrain.cells_across(), 192, "the founding valley is 192 cells across")
	assert_eq(Terrain.chunk_cells(), 32, "terrain chunks are 32 cells across")
	assert_eq(Terrain.chunks_across(), 6, "the map divides into six chunks per axis")
	assert_almost_eq(Terrain.cell_size_m(), 2.0, 0.0001, "each cell is 2 m")
	assert_almost_eq(Terrain.world_size_m(), 384.0, 0.0001, "the valley spans 384 m")
