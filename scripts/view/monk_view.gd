## Draws the community. One greybox figure per `Person`, following the logical path the sim
## laid down — cell by cell at a walking pace, so panning shows a monk walking rather than
## gliding. Presentation only: it reads `Population.get_person_view` every frame and writes
## nothing back. The proper rigged .glb with a walk-bob shader is an art-pass job (Roadmap
## 3.8); this is the box that proves the day works.
extends Node3D

var _walk_speed: float = 1.5
var _lerp_rate: float = 3.5
var _bob_height: float = 0.06
var _bob_hz: float = 2.1

var _figures: Dictionary = {}   ## person id -> _Figure


func _ready() -> void:
	_walk_speed = Tuning.get_num("agents.view_walk_speed_mps")
	_lerp_rate = Tuning.get_num("agents.view_lerp_rate")
	_bob_height = Tuning.get_num("agents.walk_bob_height_m")
	_bob_hz = Tuning.get_num("agents.walk_bob_hz")


func _process(delta: float) -> void:
	for id in Population.person_ids():
		var view: Dictionary = Population.get_person_view(id)
		if view.is_empty():
			continue
		var figure: _Figure = _figures.get(id)
		if figure == null:
			figure = _spawn(id, view)
		figure.update(view, delta, _walk_speed, _lerp_rate, _bob_height, _bob_hz)

	# Drop figures for anyone who has left the community.
	for id in _figures.keys():
		if not Population.person_ids().has(id):
			(_figures[id] as _Figure).root.queue_free()
			_figures.erase(id)


func _spawn(id: int, view: Dictionary) -> _Figure:
	var figure := _Figure.new()
	figure.build(view["order"], view["person_class"])
	figure.root.position = view["world_pos"]
	figure.visual_pos = view["world_pos"]
	add_child(figure.root)
	_figures[id] = figure
	return figure


## One rendered person: a body, a head, and a follower that walks the sim's path.
class _Figure:
	var root: Node3D
	var _pivot: Node3D
	var _pack: MeshInstance3D
	var visual_pos: Vector3
	var _visual_path: Array[Vector3] = []
	var _bob_phase: float = 0.0

	func build(order: int, person_class: int) -> void:
		root = Node3D.new()
		root.name = "Monk"
		_pivot = Node3D.new()
		root.add_child(_pivot)

		var habit := "habit_white" if order == Monastic.Order.CISTERCIAN else "habit_black"
		if person_class == Monastic.Class.CONVERSUS:
			habit = "russet"
		elif person_class == Monastic.Class.FAMULUS:
			habit = "leather"

		var body := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.28
		capsule.height = 1.62
		body.mesh = capsule
		body.position = Vector3(0.0, 0.9, 0.0)
		body.material_override = _tint(habit)
		_pivot.add_child(body)

		var head := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.16
		sphere.height = 0.32
		head.mesh = sphere
		head.position = Vector3(0.0, 1.82, 0.0)
		head.material_override = _tint("skin_pale")
		_pivot.add_child(head)

		# Phase 4.7: a carried sack, shown only while `carrying_qty > 0` — small, but it is what
		# makes hauling read as hauling rather than a monk walking for no visible reason.
		_pack = MeshInstance3D.new()
		var sack := BoxMesh.new()
		sack.size = Vector3(0.34, 0.34, 0.24)
		_pack.mesh = sack
		_pack.position = Vector3(0.0, 1.0, -0.32)
		_pack.material_override = _tint("oak_fresh")
		_pack.visible = false
		_pivot.add_child(_pack)

	func update(view: Dictionary, delta: float, walk_speed: float, lerp_rate: float,
			bob_height: float, bob_hz: float) -> void:
		var sim_pos: Vector3 = view["world_pos"]
		var path_world: Array = view["path_world"]
		_pack.visible = int(view.get("carrying_qty", 0)) > 0

		# Adopt the sim's path when we have none, or when we have drifted too far behind it.
		if (_visual_path.is_empty() and not path_world.is_empty()) or visual_pos.distance_to(sim_pos) > 8.0:
			_visual_path = path_world.duplicate()

		var moving := false
		if not _visual_path.is_empty():
			var target: Vector3 = _visual_path[0]
			var to_target := target - visual_pos
			var reach := walk_speed * delta
			if to_target.length() <= reach:
				visual_pos = target
				_visual_path.remove_at(0)
			else:
				visual_pos += to_target.normalized() * reach
			moving = true
			var flat := Vector3(to_target.x, 0.0, to_target.z)
			if flat.length() > 0.01:
				var yaw := atan2(flat.x, flat.z)
				root.rotation.y = lerp_angle(root.rotation.y, yaw, clampf(delta * 8.0, 0.0, 1.0))
		else:
			# Settle onto the sim position.
			visual_pos = visual_pos.lerp(sim_pos, clampf(delta * lerp_rate, 0.0, 1.0))

		root.position = visual_pos

		if moving:
			_bob_phase += delta * bob_hz * TAU
			_pivot.position.y = absf(sin(_bob_phase)) * bob_height
		else:
			_bob_phase = 0.0
			_pivot.position.y = lerpf(_pivot.position.y, 0.0, clampf(delta * 6.0, 0.0, 1.0))

	func _tint(palette_key: String) -> StandardMaterial3D:
		var material := StandardMaterial3D.new()
		material.albedo_color = Palette.of(palette_key)
		material.roughness = 0.95
		return material
