class_name Unit
extends CharacterBody3D

# ── Enums ────────────────────────────────────────────────────────────────────
enum UnitType  { WORKER, SOLDIER }
enum UnitState { IDLE, MOVING, GATHERING_WALK, GATHERING, RETURNING }

# ── Identity — set unit_id BEFORE adding to scene tree ───────────────────────
var unit_id     : String   = "levy_spearman"

# Loaded from Data in _ready(); set unit_id first
var unit_type    : UnitType = UnitType.SOLDIER
var unit_color   : Color    = Color(0.35, 0.60, 1.0)
var supply_cost  : int      = 1
var max_hp       : int      = 80
var hp           : int      = 80
var speed        : float    = 5.5

# Combat stats (used in Phase 5+; stored here so attack logic can read them)
var damage          : int   = 12
var attack_range    : float = 1.8
var attack_interval : float = 1.4

# Gathering stats (non-zero for workers only)
var gather_amount : int   = 0
var gather_time   : float = 0.0
var visual_scale  : float = 1.0

# ── State ─────────────────────────────────────────────────────────────────────
var is_selected := false

# ── Movement ──────────────────────────────────────────────────────────────────
var _target_pos := Vector3.ZERO
var _has_target := false

# ── Economy state machine ──────────────────────────────────────────────────────
var state          : UnitState = UnitState.IDLE
var gather_target  : ResourceNode = null
var deposit_target : Building     = null
var carry_gold     : int          = 0
var gather_timer   : float        = 0.0

# ── Visuals ───────────────────────────────────────────────────────────────────
var _ring : MeshInstance3D

signal deposited_gold(amount: int)

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	collision_layer = 2
	collision_mask  = 1

	# Load all stats from Data; unit_id must be set before add_child()
	var udata : Dictionary = Data.UNITS.get(unit_id, {})
	var is_worker_flag : bool = udata.get("is_worker", false)
	unit_type        = UnitType.WORKER if is_worker_flag else UnitType.SOLDIER
	unit_color       = udata.get("color",            Color(0.40, 0.40, 0.40))
	supply_cost      = udata.get("supply_cost",      1)
	max_hp           = udata.get("hp",               80)
	hp               = max_hp
	speed            = udata.get("speed",            5.5)
	damage           = udata.get("damage",           12)
	attack_range     = udata.get("attack_range",     1.8)
	attack_interval  = udata.get("attack_interval",  1.4)
	gather_amount    = udata.get("gather_amount",    0)
	gather_time      = udata.get("gather_time",      0.0)
	visual_scale     = udata.get("visual_scale",     1.0)

	_target_pos = global_position
	_build_visuals()

# ── Visual construction ───────────────────────────────────────────────────────

func _build_visuals() -> void:
	var is_worker    : bool  = unit_type == UnitType.WORKER
	var base_radius  : float = 0.30 if is_worker else 0.35
	var base_height  : float = 0.90 if is_worker else 1.00
	var base_offset  : float = 0.55 if is_worker else 0.65
	var radius       : float = base_radius * visual_scale
	var height       : float = base_height * visual_scale
	var y_offset     : float = base_offset * visual_scale

	# Capsule body
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = unit_color
	body_mat.roughness    = 1.0
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius   = radius
	body_mesh.height   = height
	body_mesh.material = body_mat
	var body := MeshInstance3D.new()
	body.name     = "Body"
	body.mesh     = body_mesh
	body.position = Vector3(0.0, y_offset, 0.0)
	add_child(body)

	# Collision capsule
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = height
	var col := CollisionShape3D.new()
	col.shape    = cap
	col.position = Vector3(0.0, y_offset, 0.0)
	add_child(col)

	# Selection ring (glowing disc at feet)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color               = Color(0.1, 1.0, 0.35)
	ring_mat.emission_enabled           = true
	ring_mat.emission                   = Color(0.1, 1.0, 0.35)
	ring_mat.emission_energy_multiplier = 1.5
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius    = radius + 0.18
	ring_mesh.bottom_radius = ring_mesh.top_radius
	ring_mesh.height        = 0.05
	ring_mesh.rings         = 1
	ring_mesh.material      = ring_mat
	_ring          = MeshInstance3D.new()
	_ring.name     = "Ring"
	_ring.mesh     = ring_mesh
	_ring.position = Vector3(0.0, 0.03, 0.0)
	_ring.visible  = false
	add_child(_ring)

# ── Physics ───────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if state == UnitState.GATHERING:
		velocity      = Vector3.ZERO
		gather_timer -= delta
		if gather_timer <= 0.0:
			_complete_gather()
		move_and_slide()
	else:
		_apply_movement(delta)
		if not _has_target:
			_on_arrived()

func _apply_movement(delta: float) -> void:
	if not _has_target:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	var to_target := _target_pos - global_position
	to_target.y   = 0.0
	if to_target.length() > 0.15:
		velocity = to_target.normalized() * speed
		var look_pos := global_position + Vector3(to_target.x, 0.0, to_target.z).normalized()
		look_at(look_pos, Vector3.UP)
	else:
		global_position.x = _target_pos.x
		global_position.z = _target_pos.z
		velocity    = Vector3.ZERO
		_has_target = false
	move_and_slide()

func _on_arrived() -> void:
	match state:
		UnitState.GATHERING_WALK:
			if gather_target != null and not gather_target.is_depleted():
				state        = UnitState.GATHERING
				gather_timer = gather_time  # unit's own gather_time from Data
			else:
				state = UnitState.IDLE

		UnitState.RETURNING:
			if carry_gold > 0:
				deposited_gold.emit(carry_gold)
				carry_gold = 0
			if gather_target != null and not gather_target.is_depleted() and deposit_target != null:
				state = UnitState.GATHERING_WALK
				_set_target(gather_target.global_position)
			else:
				state = UnitState.IDLE

		UnitState.MOVING:
			state = UnitState.IDLE

func _complete_gather() -> void:
	carry_gold = 0
	if gather_target != null and not gather_target.is_depleted():
		carry_gold = gather_target.try_gather(gather_amount)  # pass unit's carry capacity

	if carry_gold > 0 and deposit_target != null:
		state = UnitState.RETURNING
		_set_target(deposit_target.get_spawn_pos())
	else:
		gather_target = null
		state         = UnitState.IDLE

# ── Public API ────────────────────────────────────────────────────────────────

func select(sel: bool) -> void:
	is_selected = sel
	if _ring:
		_ring.visible = sel

func move_to(pos: Vector3) -> void:
	gather_target  = null
	deposit_target = null
	state          = UnitState.MOVING
	_set_target(pos)

func gather_from(node: ResourceNode, deposit_bldg: Building) -> void:
	gather_target  = node
	deposit_target = deposit_bldg
	state          = UnitState.GATHERING_WALK
	_set_target(node.global_position)

func _set_target(pos: Vector3) -> void:
	_target_pos = Vector3(pos.x, global_position.y, pos.z)
	_has_target = true
