class_name Building
extends StaticBody3D

const TRAIN_COSTS : Dictionary = { "worker": 50 }
const TRAIN_TIMES : Dictionary = { "worker": 8.0 }

var supply_provided : int    = 10
var owner_id        : String = ""

var production_queue : Array[String] = []
var production_timer : float         = 0.0

signal production_complete(unit_type: String, spawn_pos: Vector3)

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	collision_layer = 3  # building layer
	collision_mask  = 0
	_build_visuals()

func _process(delta: float) -> void:
	if production_queue.is_empty():
		return
	production_timer -= delta
	if production_timer <= 0.0:
		var unit_type := production_queue.pop_front()
		production_complete.emit(unit_type, get_spawn_pos())
		if not production_queue.is_empty():
			production_timer = TRAIN_TIMES.get(production_queue[0], 8.0)

# ── Public API ───────────────────────────────────────────────────────────────

func enqueue(unit_type: String) -> bool:
	if production_queue.size() >= 5:
		return false
	production_queue.append(unit_type)
	if production_queue.size() == 1:
		production_timer = TRAIN_TIMES.get(unit_type, 8.0)
	return true

func get_spawn_pos() -> Vector3:
	# Spawn new units just outside the building's east side
	return global_position + Vector3(4.0, 0.0, 0.0)

func get_progress() -> float:
	if production_queue.is_empty():
		return -1.0
	var total : float = TRAIN_TIMES.get(production_queue[0], 8.0)
	return clampf(1.0 - (production_timer / total), 0.0, 1.0)

# ── Visuals ───────────────────────────────────────────────────────────────────

func _build_visuals() -> void:
	# Base hall — wide stone block
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.50, 0.46, 0.42)
	base_mat.roughness    = 1.0
	var base_mesh := BoxMesh.new()
	base_mesh.size     = Vector3(5.0, 2.5, 5.0)
	base_mesh.material = base_mat
	var base_vis := MeshInstance3D.new()
	base_vis.mesh     = base_mesh
	base_vis.position = Vector3(0.0, 1.25, 0.0)
	add_child(base_vis)

	# Central tower — darker, taller
	var tower_mat := StandardMaterial3D.new()
	tower_mat.albedo_color = Color(0.42, 0.38, 0.35)
	tower_mat.roughness    = 1.0
	var tower_mesh := BoxMesh.new()
	tower_mesh.size     = Vector3(2.0, 2.5, 2.0)
	tower_mesh.material = tower_mat
	var tower_vis := MeshInstance3D.new()
	tower_vis.mesh     = tower_mesh
	tower_vis.position = Vector3(0.0, 3.75, 0.0)
	add_child(tower_vis)

	# Collision (bounding box for the full structure)
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.0, 5.0, 5.0)
	var col := CollisionShape3D.new()
	col.shape    = shape
	col.position = Vector3(0.0, 2.5, 0.0)
	add_child(col)
