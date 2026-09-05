## Every player-placed `Building`, drawn from its type's authored model, its construction state
## and its `build_progress`. Presentation only — reads `Buildings` every frame and writes nothing
## back, same contract as `monk_view.gd`.
##
## **A site is the finished model, revealed from the ground up.** `build_progress` drives the
## `build_height_m` uniform on `assets/materials/building.gdshader`, which discards everything
## above that height in the model's own space: a plot shows its stone plinth first, then its
## walls, and its roof only in the last of the work. That is both the honest picture of a
## construction site and cheaper than authoring part-built variants — one uniform per site, and
## it comes free for every building type added later.
##
## Scaffolding stands around a site while it is under construction and is dropped the moment it
## completes, so "being worked on" reads at a glance from any zoom, which a partial model alone
## does not give you.
##
## A type with no `.glb` falls back to the original greybox box (`BuildingModels` returns null),
## so a building type added to `data/buildings.json` before anyone models it still places, still
## builds, and still renders — just plainly.
extends Node3D

const MATERIAL_PATH := "res://assets/materials/m_building.tres"

## Fallback wall height by category, for a type with no model yet. `data/buildings.json` carries
## a 2D floor plan and no height, so this stays a presentation guess — the authored models are
## where a building's real height lives.
const _FULL_HEIGHT_M := {"production": 3.2, "storage": 3.8}
const _DEFAULT_HEIGHT_M := 3.0
const _SITE_HEIGHT_M := 0.15   ## a cleared, staked-out plot before any wall has risen

const _SCAFFOLD_COLOUR := "oak_fresh"
const _STAKE_COLOUR := "oak_weathered"
const _PLOT_COLOUR := "soil"

var _base_material: ShaderMaterial = null
var _fallback_materials: Dictionary = {}
var _sites: Dictionary = {}   ## building id -> _Site
var _seasons := SeasonBlender.new()
var _snow: float = 0.0


func _ready() -> void:
	_base_material = load(MATERIAL_PATH)
	SimClock.day_passed.connect(_on_day_passed)
	_apply_season()


func _on_day_passed(_day_of_year: int) -> void:
	_apply_season()


## Snow is per-material, and every site owns its own material instance (it needs its own
## `build_height_m`), so the seasonal value is cached here and pushed into each site as it
## refreshes rather than walked over every site on the day it changes.
func _apply_season() -> void:
	var state := _seasons.sample(SimClock.day_of_year())
	if state.is_empty():
		return
	_snow = state["snow_coverage"]


func _process(_delta: float) -> void:
	var ids := Buildings.building_ids()
	for id in ids:
		var site: _Site = _sites.get(id)
		if site == null:
			site = _Site.new()
			site.build(_base_material)
			add_child(site.root)
			_sites[id] = site
		_refresh(site, id)

	for id in _sites.keys():
		if not ids.has(id):
			(_sites[id] as _Site).root.queue_free()
			_sites.erase(id)


func _refresh(site: _Site, id: int) -> void:
	var b := Buildings.get_building(id)
	var type := Buildings.get_type(b.type_id)

	var footprint_m := Vector2(b.footprint) * Terrain.cell_size_m()
	var centre := Vector2(b.anchor) + Vector2(b.footprint) * 0.5
	var ground := Terrain.cell_to_world(int(floor(centre.x)), int(floor(centre.y)))
	site.root.position = ground

	var progress := clampf(b.build_progress, 0.0, 1.0)
	var planned := (
		b.construction_state == Building.State.PLANNED
		or b.construction_state == Building.State.MATERIALS_PENDING
	)
	var building := b.construction_state == Building.State.UNDER_CONSTRUCTION
	var complete := b.construction_state == Building.State.COMPLETE

	var mesh := BuildingModels.mesh_for(b.type_id)
	if mesh != null:
		# The model is authored to the unrotated footprint, so the same rotation the simulation
		# applied to the footprint is applied to the mesh.
		site.show_model(mesh, deg_to_rad(float(b.rotation_deg)), _snow)
		var model_height: float = mesh.get_aabb().size.y
		# Nothing of the building shows until the plot is being worked; then it rises.
		var revealed := 0.0
		if complete:
			revealed = model_height + 1.0
		elif building:
			revealed = model_height * progress
		site.set_revealed(revealed)
	else:
		site.show_fallback_box(
			footprint_m,
			_fallback_height(type, b.construction_state, progress),
			_fallback_material(str(type.get("colour", "soil")))
		)

	site.show_plot(planned or building, footprint_m)
	site.show_scaffold(building, footprint_m, _fallback_height(type, Building.State.COMPLETE, 1.0)
		if mesh == null else mesh.get_aabb().size.y)


func _fallback_height(type: Dictionary, state: Building.State, progress: float) -> float:
	var full: float = _FULL_HEIGHT_M.get(str(type.get("category", "")), _DEFAULT_HEIGHT_M)
	match state:
		Building.State.PLANNED, Building.State.MATERIALS_PENDING:
			return _SITE_HEIGHT_M
		Building.State.UNDER_CONSTRUCTION:
			return lerpf(_SITE_HEIGHT_M, full, progress)
		_:
			return full


func _fallback_material(palette_key: String) -> StandardMaterial3D:
	if not _fallback_materials.has(palette_key):
		var material := StandardMaterial3D.new()
		material.albedo_color = Palette.of(palette_key)
		material.roughness = 0.9
		material.metallic = 0.0
		_fallback_materials[palette_key] = material
	return _fallback_materials[palette_key]


## One rendered building: its model (or a greybox box), the cleared plot under it, and the
## scaffolding that stands around it while it is being built.
class _Site:
	var root: Node3D

	var _model: MeshInstance3D
	var _material: ShaderMaterial
	var _fallback: MeshInstance3D
	var _fallback_mesh: BoxMesh
	var _plot: MeshInstance3D
	var _plot_mesh: BoxMesh
	var _scaffold: Node3D
	var _scaffold_posts: Array[MeshInstance3D] = []

	func build(base_material: ShaderMaterial) -> void:
		root = Node3D.new()
		root.name = "BuildingSite"
		# Each site needs its own `build_height_m`, so each gets its own material instance. They
		# still share one shader, so this costs a uniform block per building, not a pipeline.
		_material = base_material.duplicate() if base_material != null else null

		_model = MeshInstance3D.new()
		_model.name = "Model"
		_model.material_override = _material
		_model.visible = false
		root.add_child(_model)

	func show_model(mesh: Mesh, yaw_radians: float, snow: float) -> void:
		if _model.mesh != mesh:
			_model.mesh = mesh
		_model.rotation.y = yaw_radians
		_model.visible = true
		if _fallback != null:
			_fallback.visible = false
		if _material != null:
			_material.set_shader_parameter("snow_amount", snow)

	func set_revealed(height_m: float) -> void:
		if _material != null:
			_material.set_shader_parameter("build_height_m", height_m)

	func show_fallback_box(footprint_m: Vector2, height: float, material: Material) -> void:
		_model.visible = false
		if _fallback == null:
			_fallback_mesh = BoxMesh.new()
			_fallback = MeshInstance3D.new()
			_fallback.name = "Greybox"
			_fallback.mesh = _fallback_mesh
			root.add_child(_fallback)
		_fallback_mesh.size = Vector3(footprint_m.x, height, footprint_m.y)
		_fallback.position = Vector3(0.0, height * 0.5, 0.0)
		_fallback.material_override = material
		_fallback.visible = true

	## The scraped, staked-out plot a site sits on before and during construction. It disappears
	## on completion, when the building's own plinth takes over the job of grounding it.
	func show_plot(visible_now: bool, footprint_m: Vector2) -> void:
		if not visible_now:
			if _plot != null:
				_plot.visible = false
			return
		if _plot == null:
			_plot_mesh = BoxMesh.new()
			_plot = MeshInstance3D.new()
			_plot.name = "Plot"
			_plot.mesh = _plot_mesh
			var material := StandardMaterial3D.new()
			material.albedo_color = Palette.of(_PLOT_COLOUR)
			material.roughness = 0.95
			_plot.material_override = material
			root.add_child(_plot)
		_plot_mesh.size = Vector3(footprint_m.x, 0.14, footprint_m.y)
		_plot.position = Vector3(0.0, 0.07, 0.0)
		_plot.visible = true

	func show_scaffold(visible_now: bool, footprint_m: Vector2, full_height: float) -> void:
		if not visible_now:
			if _scaffold != null:
				_scaffold.visible = false
			return
		if _scaffold == null:
			_scaffold = Node3D.new()
			_scaffold.name = "Scaffold"
			root.add_child(_scaffold)
			var material := StandardMaterial3D.new()
			material.albedo_color = Palette.of(_SCAFFOLD_COLOUR)
			material.roughness = 0.9
			var ledger_material := StandardMaterial3D.new()
			ledger_material.albedo_color = Palette.of(_STAKE_COLOUR)
			ledger_material.roughness = 0.9
			# Four standards and one ring of ledgers: the least geometry that still reads as
			# scaffolding rather than as four sticks.
			for i in 4:
				var post := MeshInstance3D.new()
				post.mesh = BoxMesh.new()
				post.material_override = material
				_scaffold.add_child(post)
				_scaffold_posts.append(post)
			for i in 4:
				var ledger := MeshInstance3D.new()
				ledger.mesh = BoxMesh.new()
				ledger.material_override = ledger_material
				_scaffold.add_child(ledger)
				_scaffold_posts.append(ledger)

		var half := footprint_m * 0.5
		var height: float = maxf(full_height * 1.08, 1.6)
		var corners := [
			Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(half.x, half.y), Vector2(-half.x, half.y),
		]
		for i in 4:
			var post := _scaffold_posts[i]
			(post.mesh as BoxMesh).size = Vector3(0.18, height, 0.18)
			post.position = Vector3(corners[i].x, height * 0.5, corners[i].y)
		# Ledgers span between adjacent standards, just below the top of the lift.
		var ledger_y: float = height * 0.66
		for i in 4:
			var a: Vector2 = corners[i]
			var c: Vector2 = corners[(i + 1) % 4]
			var ledger := _scaffold_posts[4 + i]
			var span := (c - a).length()
			var along_x := absf(c.x - a.x) > absf(c.y - a.y)
			(ledger.mesh as BoxMesh).size = (
				Vector3(span, 0.12, 0.12) if along_x else Vector3(0.12, 0.12, span)
			)
			var mid := (a + c) * 0.5
			ledger.position = Vector3(mid.x, ledger_y, mid.y)
		_scaffold.visible = true
