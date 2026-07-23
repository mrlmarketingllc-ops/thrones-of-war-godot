extends Node3D

# ── Constants ───────────────────────────────────────────────────────────────
const MAP_SIZE      := 100.0  # world units (each cell ≈ 1 unit)
const CAM_PAN_SPEED := 25.0
const CAM_ZOOM_MIN  := 8.0
const CAM_ZOOM_MAX  := 42.0

# ── Camera nodes (created in code) ─────────────────────────────────────────
var camera_rig : Node3D
var camera     : Camera3D

# ── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	_register_input_actions()
	_build_scene()

# ── Scene construction ──────────────────────────────────────────────────────

func _build_scene() -> void:
	_setup_sky()
	_setup_lighting()
	_setup_ground()
	_setup_camera()

func _setup_sky() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color     = Color(0.15, 0.20, 0.35)
	sky_mat.sky_horizon_color = Color(0.50, 0.40, 0.28)
	sky_mat.ground_bottom_color = Color(0.18, 0.18, 0.18)

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.sky = sky
	env.background_mode       = Environment.BG_SKY
	env.ambient_light_source  = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy  = 0.6

	($WorldEnvironment as WorldEnvironment).environment = env

func _setup_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name              = "Sun"
	sun.light_energy      = 1.8
	sun.shadow_enabled    = true
	sun.rotation_degrees  = Vector3(-55.0, -30.0, 0.0)
	add_child(sun)

func _setup_ground() -> void:
	# Visual mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.24, 0.40, 0.18)
	mat.roughness    = 1.0

	var plane := PlaneMesh.new()
	plane.size     = Vector2(MAP_SIZE, MAP_SIZE)
	plane.material = mat

	var vis := MeshInstance3D.new()
	vis.name     = "GroundMesh"
	vis.mesh     = plane
	vis.position = Vector3(MAP_SIZE * 0.5, 0.0, MAP_SIZE * 0.5)
	add_child(vis)

	# Collision body for mouse-pick raycasts (used later for unit placement)
	var body  := StaticBody3D.new()
	body.name = "Ground"
	body.position = Vector3(MAP_SIZE * 0.5, 0.0, MAP_SIZE * 0.5)

	var col   := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(MAP_SIZE, 0.2, MAP_SIZE)
	col.shape  = shape
	body.add_child(col)
	add_child(body)

func _setup_camera() -> void:
	# CameraRig pans across the map; Camera3D is its angled child
	camera_rig          = Node3D.new()
	camera_rig.name     = "CameraRig"
	camera_rig.position = Vector3(MAP_SIZE * 0.5, 0.0, MAP_SIZE * 0.5)
	add_child(camera_rig)

	camera                  = Camera3D.new()
	camera.name             = "Camera3D"
	camera.position         = Vector3(0.0, 18.0, 14.0)
	camera.rotation_degrees = Vector3(-55.0, 0.0, 0.0)
	camera_rig.add_child(camera)

# ── Input action registration ───────────────────────────────────────────────

func _register_input_actions() -> void:
	var map : Dictionary = {
		"cam_left":  [KEY_A, KEY_LEFT],
		"cam_right": [KEY_D, KEY_RIGHT],
		"cam_up":    [KEY_W, KEY_UP],
		"cam_down":  [KEY_S, KEY_DOWN],
	}
	for action: String in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode: Key in map[action]:
			var ev := InputEventKey.new()
			ev.keycode = keycode
			InputMap.action_add_event(action, ev)

# ── Per-frame ───────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_pan_camera(delta)

func _pan_camera(delta: float) -> void:
	if camera == null:
		return
	var move := Vector2.ZERO
	if Input.is_action_pressed("cam_left"):  move.x -= 1.0
	if Input.is_action_pressed("cam_right"): move.x += 1.0
	if Input.is_action_pressed("cam_up"):    move.y -= 1.0
	if Input.is_action_pressed("cam_down"):  move.y += 1.0
	if move == Vector2.ZERO:
		return

	# Decompose camera orientation into flat XZ directions
	var cam_right   := camera.global_transform.basis.x.normalized()
	var cam_forward := -camera.global_transform.basis.z
	cam_forward.y   = 0.0
	cam_forward     = cam_forward.normalized()

	var delta_pos := (cam_right * move.x + cam_forward * -move.y) * CAM_PAN_SPEED * delta
	camera_rig.position += delta_pos
	camera_rig.position.x = clamp(camera_rig.position.x, 0.0, MAP_SIZE)
	camera_rig.position.z = clamp(camera_rig.position.z, 0.0, MAP_SIZE)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			match mb.button_index:
				MOUSE_BUTTON_WHEEL_UP:   _zoom(-3.0)
				MOUSE_BUTTON_WHEEL_DOWN: _zoom( 3.0)

func _zoom(amount: float) -> void:
	if camera == null:
		return
	var new_y := clamp(camera.position.y + amount, CAM_ZOOM_MIN, CAM_ZOOM_MAX)
	var ratio  := new_y / camera.position.y if camera.position.y != 0.0 else 1.0
	camera.position.y = new_y
	camera.position.z = clamp(camera.position.z * ratio, CAM_ZOOM_MIN * 0.7, CAM_ZOOM_MAX * 0.7)
