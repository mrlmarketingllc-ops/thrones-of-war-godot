class_name ResourceNode
extends StaticBody3D

const GATHER_AMOUNT : int   = 15   # gold extracted per trip
const GATHER_TIME   : float = 2.5  # seconds to fill one load

var gold_remaining : int = 400

func _ready() -> void:
	collision_layer = 4  # resource-node layer (raycasted on right-click)
	collision_mask  = 0
	_build_visuals()

func _build_visuals() -> void:
	# Three stacked golden discs that shrink as gold depletes
	for i in 3:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.78 - i * 0.06, 0.05)
		mat.roughness    = 0.25
		mat.metallic     = 0.85

		var mesh := CylinderMesh.new()
		mesh.top_radius    = 0.65 - i * 0.1
		mesh.bottom_radius = 0.65 - i * 0.1
		mesh.height        = 0.28
		mesh.material      = mat

		var vis := MeshInstance3D.new()
		vis.mesh     = mesh
		vis.position = Vector3(0.0, 0.18 + i * 0.28, 0.0)
		add_child(vis)

	# Collision cylinder
	var shape := CylinderShape3D.new()
	shape.radius = 0.8
	shape.height = 1.0
	var col := CollisionShape3D.new()
	col.shape    = shape
	col.position = Vector3(0.0, 0.45, 0.0)
	add_child(col)

func try_gather() -> int:
	if gold_remaining <= 0:
		return 0
	var amount := mini(GATHER_AMOUNT, gold_remaining)
	gold_remaining -= amount
	# Shrink visually as gold depletes
	var ratio := clampf(float(gold_remaining) / 400.0, 0.15, 1.0)
	scale      = Vector3.ONE * ratio
	return amount

func is_depleted() -> bool:
	return gold_remaining <= 0
