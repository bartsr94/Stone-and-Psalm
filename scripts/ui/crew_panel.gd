## Worker-assignment panel for crews (roadmap 4.9, extended 5.1 for production).
##
## Lists every building with a crew worth showing: a site `UNDER_CONSTRUCTION`, or a `COMPLETE`
## production building now that `Production` (roadmap 5.1) gives its `worker_slots` a recipe to
## run — the same eligibility `Buildings.assign_worker` enforces, so a row here is never a promise
## the sim cannot keep (`SIMULATION_SPEC.md` §6.5/§7.3).
##
## Presentation only, built in code the way `hud.gd` and `site_status_overlay.gd` are. It reads
## `Buildings`/`Production`/`Population` and writes nothing except through
## `Buildings.assign_worker`/`unassign_worker` — the same headless API `test_buildings.gd` and
## `test_labour.gd` exercise directly. Toggle with `C` (`crew_toggle`).
class_name CrewPanel
extends CanvasLayer

const THEME_PATH := "res://ui/theme/stone_and_psalm_theme.tres"

var _visible_panel: bool = false
var _root: Control
var _panel: PanelContainer
var _pool_label: Label
var _rows_column: VBoxContainer


func _ready() -> void:
	layer = 16

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = load(THEME_PATH)
	add_child(_root)

	# Top-centre: every corner is already spoken for — `SiteStatusOverlay` (layer 20) owns
	# top-left, `Hud` owns top-right and bottom-right, `HorariumRing` owns bottom-left, and
	# `SiteStatusOverlay`'s own controls strip sits centre-bottom.
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.position = Vector2(-180.0, 24.0)
	_panel.custom_minimum_size = Vector2(360.0, 0.0)
	_panel.visible = false
	_root.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_panel.add_child(column)

	var title := Label.new()
	title.text = "CREWS"
	title.add_theme_font_size_override("font_size", 16)
	column.add_child(title)

	_pool_label = Label.new()
	_pool_label.add_theme_font_size_override("font_size", 13)
	_pool_label.add_theme_color_override("font_color", Color(0.71, 0.69, 0.62))
	column.add_child(_pool_label)

	column.add_child(HSeparator.new())

	_rows_column = VBoxContainer.new()
	_rows_column.add_theme_constant_override("separation", 4)
	column.add_child(_rows_column)


func _process(_delta: float) -> void:
	if _visible_panel:
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("crew_toggle"):
		_visible_panel = not _visible_panel
		_panel.visible = _visible_panel
		if _visible_panel:
			_refresh()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _visible_panel


## Test-support accessors, the same shape as `hud.gd`'s `speed_buttons()`.
func site_ids() -> Array:
	return _sites()


func pool_size() -> int:
	return _pool_ids().size()


func assign_button_for(building_id: int) -> Button:
	var row := _rows_column.find_child("Row_%d" % building_id, false, false)
	return null if row == null else row.get_node("PlusButton") as Button


func unassign_button_for(building_id: int) -> Button:
	var row := _rows_column.find_child("Row_%d" % building_id, false, false)
	return null if row == null else row.get_node("MinusButton") as Button


## Sites the panel lists: under construction, or a complete production building — either way with
## at least one worker slot — sorted by id so the row order is stable from one refresh to the
## next. Mirrors `Buildings._accepts_a_crew`'s eligibility exactly (a row here is only ever a
## building `assign_worker` will actually accept).
func _sites() -> Array:
	var ids := []
	for id in Buildings.building_ids():
		if Buildings.worker_slots(id) <= 0:
			continue
		var b := Buildings.get_building(id)
		var is_producing_type: bool = str(Buildings.get_type(b.type_id).get("category", "")) == "production"
		var eligible: bool = (
			b.construction_state == Building.State.UNDER_CONSTRUCTION
			or (b.construction_state == Building.State.COMPLETE and is_producing_type)
		)
		if eligible:
			ids.append(id)
	ids.sort()
	return ids


## Everyone not currently pinned to a construction crew, sorted by id.
func _pool_ids() -> Array:
	var ids := []
	for pid in Population.person_ids():
		if Buildings.building_for_worker(pid) == -1:
			ids.append(pid)
	ids.sort()
	return ids


func _refresh() -> void:
	var pool := _pool_ids()
	_pool_label.text = "Laborer pool: %d" % pool.size()

	for child in _rows_column.get_children():
		child.queue_free()

	for id in _sites():
		_rows_column.add_child(_build_row(id, pool))


func _build_row(id: int, pool: Array) -> Control:
	var b := Buildings.get_building(id)
	var type_def := Buildings.get_type(b.type_id)
	var assigned := Buildings.worker_count(id)
	var capacity := Buildings.worker_slots(id)

	var row := HBoxContainer.new()
	row.name = "Row_%d" % id
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = "%s  (%d/%d)  %s" % [str(type_def.get("label", b.type_id)), assigned, capacity, _status_text(b)]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var minus := Button.new()
	minus.name = "MinusButton"
	minus.text = "−"
	minus.focus_mode = Control.FOCUS_NONE
	minus.custom_minimum_size = Vector2(28.0, 0.0)
	minus.disabled = assigned <= 0
	minus.pressed.connect(_on_unassign.bind(id))
	row.add_child(minus)

	var plus := Button.new()
	plus.name = "PlusButton"
	plus.text = "+"
	plus.focus_mode = Control.FOCUS_NONE
	plus.custom_minimum_size = Vector2(28.0, 0.0)
	plus.disabled = assigned >= capacity or pool.is_empty()
	plus.pressed.connect(_on_assign.bind(id))
	row.add_child(plus)

	return row


## What a row's crew is actually doing right now, so "assigned but nothing to show" (a production
## site out of inputs for its next batch) doesn't look identical to real work in progress.
func _status_text(b: Building) -> String:
	if b.construction_state == Building.State.UNDER_CONSTRUCTION:
		return "· building"
	if b.active_recipe != "":
		return "· producing %s" % str(Production.get_recipe(b.active_recipe).get("label", b.active_recipe))
	if Production.can_produce(b.id):
		return "· idle"
	return "· nothing to produce"


func _on_assign(building_id: int) -> void:
	var pool := _pool_ids()
	if pool.is_empty():
		return
	Buildings.assign_worker(building_id, int(pool[0]))
	_refresh()


func _on_unassign(building_id: int) -> void:
	var b := Buildings.get_building(building_id)
	if b == null or b.assigned_workers.is_empty():
		return
	var crew := b.assigned_workers.duplicate()
	crew.sort()
	Buildings.unassign_worker(int(crew[0]))
	_refresh()
