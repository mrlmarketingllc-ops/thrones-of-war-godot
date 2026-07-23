class_name Building
extends StaticBody3D

# Set building_id BEFORE adding to scene tree; stats are loaded from Data in _ready()
var building_id     : String = "great_hall"

var supply_provided : int    = 0
var owner_id        : String = ""
var net_id          : int    = 0

var production_queue : Array[String] = []
var production_timer : float         = 0.0

signal production_complete(unit_id: String, spawn_pos: Vector3)

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	collision_layer = 3
	collision_mask  = 0
	var bdata : Dictionary = Data.BUILDINGS.get(building_id, {})
	supply_provided = bdata.get("supply_provided", 0)
	_build_visuals()

func _process(delta: float) -> void:
	if production_queue.is_empty():
		return
	production_timer -= delta
	if production_timer <= 0.0:
		var unit_id : String = production_queue.pop_front()
		production_complete.emit(unit_id, get_spawn_pos())
		if not production_queue.is_empty():
			var udata      : Dictionary = Data.UNITS.get(production_queue[0], {})
			var train_time : float      = udata.get("train_time", 8.0)
			production_timer = train_time

# ── Public API ───────────────────────────────────────────────────────────────

func enqueue(unit_id: String) -> bool:
	var bdata  : Dictionary = Data.BUILDINGS.get(building_id, {})
	var trains : Array      = bdata.get("trains", [])
	if unit_id not in trains:
		return false
	if production_queue.size() >= 5:
		return false
	production_queue.append(unit_id)
	if production_queue.size() == 1:
		var udata      : Dictionary = Data.UNITS.get(unit_id, {})
		var train_time : float      = udata.get("train_time", 8.0)
		production_timer = train_time
	return true

func get_spawn_pos() -> Vector3:
	var bdata : Dictionary = Data.BUILDINGS.get(building_id, {})
	var sz    : float      = bdata.get("size", 4.0)
	return global_position + Vector3(sz * 0.8, 0.0, 0.0)

func get_progress() -> float:
	if production_queue.is_empty():
		return -1.0
	var udata : Dictionary = Data.UNITS.get(production_queue[0], {})
	var total : float      = udata.get("train_time", 8.0)
	return clampf(1.0 - (production_timer / total), 0.0, 1.0)

# ── Visuals ───────────────────────────────────────────────────────────────────

func _build_visuals() -> void:
	var bdata : Dictionary = Data.BUILDINGS.get(building_id, {})
	var sz    : float      = bdata.get("size",  4.0)
	var bcol  : Color      = bdata.get("color", Color(0.50, 0.46, 0.42))

	# Base block — full footprint, half-height
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = bcol
	base_mat.roughness    = 1.0
	var base_mesh := BoxMesh.new()
	base_mesh.size     = Vector3(sz, sz * 0.5, sz)
	base_mesh.material = base_mat
	var base_vis := MeshInstance3D.new()
	base_vis.mesh     = base_mesh
	base_vis.position = Vector3(0.0, sz * 0.25, 0.0)
	add_child(base_vis)

	# Central tower — 40% footprint, slightly darker
	var tow_mat := StandardMaterial3D.new()
	tow_mat.albedo_color = bcol * 0.82
	tow_mat.roughness    = 1.0
	var tow_mesh := BoxMesh.new()
	tow_mesh.size     = Vector3(sz * 0.4, sz * 0.5, sz * 0.4)
	tow_mesh.material = tow_mat
	var tow_vis := MeshInstance3D.new()
	tow_vis.mesh     = tow_mesh
	tow_vis.position = Vector3(0.0, sz * 0.75, 0.0)
	add_child(tow_vis)

	# Collision (full height bounding box)
	var shape := BoxShape3D.new()
	shape.size = Vector3(sz, sz, sz)
	var col := CollisionShape3D.new()
	col.shape    = shape
	col.position = Vector3(0.0, sz * 0.5, 0.0)
	add_child(col)
