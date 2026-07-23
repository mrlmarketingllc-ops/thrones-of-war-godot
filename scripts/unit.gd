class_name Unit
extends CharacterBody3D

const SPEED := 8.0

var unit_color  := Color(0.35, 0.60, 1.0)
var is_selected := false

var _target_pos := Vector3.ZERO
var _has_target := false
var _ring       : MeshInstance3D

# ── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	collision_layer = 2
	collision_mask  = 1  # collide with ground layer so move_and_slide works
	_target_pos = global_position
	_build_visuals()

# ── Visual construction (all in code — no sub-scenes needed) ────────────────

func _build_visuals() -> void:
	# Body — flat-shaded capsule in faction colour
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = unit_color
	body_mat.roughness    = 1.0

	var body_mesh := CapsuleMesh.new()
	body_mesh.radius   = 0.35
	body_mesh.height   = 1.0
	body_mesh.material = body_mat

	var body := MeshInstance3D.new()
	body.name     = "Body"
	body.mesh     = body_mesh
	body.position = Vector3(0.0, 0.65, 0.0)
	add_child(body)

	# Collision capsule aligned with body
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.0
	var col := CollisionShape3D.new()
	col.shape    = cap
	col.position = Vector3(0.0, 0.65, 0.0)
	add_child(col)

	# Selection ring — flat glowing cylinder at feet
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color               = Color(0.1, 1.0, 0.35)
	ring_mat.emission_enabled           = true
	ring_mat.emission                   = Color(0.1, 1.0, 0.35)
	ring_mat.emission_energy_multiplier = 1.5

	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius    = 0.55
	ring_mesh.bottom_radius = 0.55
	ring_mesh.height        = 0.05
	ring_mesh.rings         = 1
	ring_mesh.material      = ring_mat

	_ring          = MeshInstance3D.new()
	_ring.name     = "SelectionRing"
	_ring.mesh     = ring_mesh
	_ring.position = Vector3(0.0, 0.03, 0.0)
	_ring.visible  = false
	add_child(_ring)

# ── Physics ─────────────────────────────────────────────────────────────────

func _physics_process(_delta: float) -> void:
	if _has_target:
		var to_target := _target_pos - global_position
		to_target.y = 0.0
		if to_target.length() > 0.15:
			velocity = to_target.normalized() * SPEED
			# Face the movement direction (flat rotation only)
			var look_pos := global_position + Vector3(to_target.x, 0.0, to_target.z).normalized()
			look_at(look_pos, Vector3.UP)
		else:
			global_position.x = _target_pos.x
			global_position.z = _target_pos.z
			velocity    = Vector3.ZERO
			_has_target = false
	else:
		velocity = Vector3.ZERO

	move_and_slide()

# ── Public API ──────────────────────────────────────────────────────────────

func select(sel: bool) -> void:
	is_selected = sel
	if _ring:
		_ring.visible = sel

func move_to(pos: Vector3) -> void:
	_target_pos = Vector3(pos.x, global_position.y, pos.z)
	_has_target = true
