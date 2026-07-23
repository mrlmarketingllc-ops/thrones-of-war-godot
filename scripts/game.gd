extends Node3D

# ════════════════════════════════════════════════════════════════════════════
# 2D drag-selection box overlay
# ════════════════════════════════════════════════════════════════════════════
class SelectionBox extends Control:
	var _s := Vector2.ZERO
	var _e := Vector2.ZERO

	func draw_box(s: Vector2, e: Vector2) -> void:
		_s = s; _e = e; queue_redraw()

	func _draw() -> void:
		var r := Rect2(
			Vector2(minf(_s.x, _e.x), minf(_s.y, _e.y)),
			Vector2(absf(_e.x - _s.x), absf(_e.y - _s.y))
		)
		draw_rect(r, Color(0.05, 1.0, 0.3, 0.12), true)
		draw_rect(r, Color(0.05, 1.0, 0.3, 0.85), false, 1.5)

# ════════════════════════════════════════════════════════════════════════════
# Minimap panel (2D overlay, bottom-right corner)
# ════════════════════════════════════════════════════════════════════════════
class MinimapPanel extends Panel:
	var game_ref : Node3D = null

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if game_ref == null:
			return
		const SZ : float = 160.0
		var r := Rect2(Vector2.ZERO, Vector2(SZ, SZ))
		draw_rect(r, Color(0.10, 0.18, 0.08))

		# Resource nodes
		for rn_node in game_ref.resource_nodes:
			var rn  := rn_node as ResourceNode
			var col : Color = Color(0.90, 0.78, 0.05) if not rn.is_depleted() else Color(0.20, 0.20, 0.10)
			draw_circle(_w2m(rn.global_position), 2.5, col)

		# Units (hide enemy dots when they're in fog)
		for u_node in game_ref.all_units:
			var u := u_node as Unit
			if not u.visible and u.owner_id != "player1":
				continue
			var col : Color = Color(0.25, 0.55, 1.0) if u.owner_id == "player1" else Color(1.0, 0.22, 0.22)
			draw_circle(_w2m(u.global_position), 2.5, col)

		# Camera view indicator
		if game_ref.camera_rig != null:
			var cp : Vector3 = game_ref.camera_rig.global_position
			var tl := _w2m(cp + Vector3(-25.0, 0.0, -18.0))
			var br := _w2m(cp + Vector3( 25.0, 0.0,  18.0))
			draw_rect(Rect2(tl, br - tl), Color(1.0, 1.0, 1.0, 0.50), false, 1.0)

		draw_rect(r, Color(0.55, 0.55, 0.55), false, 1.5)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				const SZ : float = 160.0
				var ms   : float = game_ref.MAP_SIZE
				var cur_y : float = game_ref.camera_rig.position.y
				game_ref.camera_rig.position = Vector3(
					clampf(mb.position.x / SZ * ms, 0.0, ms),
					cur_y,
					clampf(mb.position.y / SZ * ms, 0.0, ms)
				)

	func _w2m(world_pos: Vector3) -> Vector2:
		const SZ : float = 160.0
		var ms   : float = game_ref.MAP_SIZE
		return Vector2(
			clampf(world_pos.x / ms * SZ, 0.0, SZ),
			clampf(world_pos.z / ms * SZ, 0.0, SZ)
		)

# ════════════════════════════════════════════════════════════════════════════
# Constants
# ════════════════════════════════════════════════════════════════════════════
const UnitScene         := preload("res://scenes/unit.tscn")
const BuildingScene     := preload("res://scenes/building.tscn")
const ResourceNodeScene := preload("res://scenes/resource_node.tscn")

const MAP_SIZE       : float = 100.0
const CAM_PAN_SPEED  : float = 25.0
const CAM_ZOOM_MIN   : float = 8.0
const CAM_ZOOM_MAX   : float = 42.0
const DRAG_THRESHOLD : float = 5.0
const EDGE_MARGIN    : int   = 20

const PLAYER_START   := Vector3(18.0, 0.0, 18.0)
const ENEMY_START    := Vector3(75.0, 0.0, 75.0)

# Fog of war
const FOG_SIZE   : int   = 25     # 25×25 pixel texture → 4 world-unit cells
const VISION_R   : float = 14.0   # vision radius per player unit (world units)

# ════════════════════════════════════════════════════════════════════════════
# State
# ════════════════════════════════════════════════════════════════════════════
var camera_rig : Node3D
var camera     : Camera3D
var sel_box    : SelectionBox
var hud_label  : Label
var hint_label : Label

var all_units     : Array = []
var all_buildings : Array = []
var selected      : Array = []

var player_faction    : String   = "north"   # change here to play a different faction
var player_gold       : int      = 150
var player_supply     : int      = 0
var player_max_supply : int      = 0
var main_building     : Building = null

var resource_nodes : Array = []

# Fog of war
var _fog_image    : Image
var _fog_texture  : ImageTexture
var _fog_explored : PackedByteArray   # 0 = never seen
var _fog_state    : PackedByteArray   # 0 = black, 1 = gray shroud, 2 = visible
var _fog_tick     : int = 0
var _minimap      : MinimapPanel

var drag_start := Vector2.ZERO
var dragging   := false

var _build_menu : bool   = false   # worker build menu open
var _build_bldg : String = ""      # building type chosen for placement
var _ai_tick    : int    = 0

# ════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	_register_input_actions()
	_build_scene()
	_setup_fog()
	_setup_ui()
	_spawn_starting_buildings()
	_spawn_resource_nodes()
	_spawn_starting_units()
	_spawn_enemy_units()

# ════════════════════════════════════════════════════════════════════════════
# Scene construction
# ════════════════════════════════════════════════════════════════════════════
func _build_scene() -> void:
	_setup_sky()
	_setup_lighting()
	_setup_ground()
	_setup_camera()

func _setup_sky() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color       = Color(0.15, 0.20, 0.35)
	sky_mat.sky_horizon_color   = Color(0.50, 0.40, 0.28)
	sky_mat.ground_bottom_color = Color(0.18, 0.18, 0.18)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.sky                  = sky
	env.background_mode      = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	($WorldEnvironment as WorldEnvironment).environment = env

func _setup_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name             = "Sun"
	sun.light_energy     = 1.8
	sun.shadow_enabled   = true
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	add_child(sun)

func _setup_ground() -> void:
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

	# Collision on layer 1 (ground) for move raycasts
	var body := StaticBody3D.new()
	body.name            = "Ground"
	body.position        = Vector3(MAP_SIZE * 0.5, 0.0, MAP_SIZE * 0.5)
	body.collision_layer = 1
	body.collision_mask  = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(MAP_SIZE, 0.2, MAP_SIZE)
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)

func _setup_camera() -> void:
	camera_rig          = Node3D.new()
	camera_rig.name     = "CameraRig"
	camera_rig.position = PLAYER_START
	add_child(camera_rig)
	camera                  = Camera3D.new()
	camera.name             = "Camera3D"
	camera.position         = Vector3(0.0, 18.0, 14.0)
	camera.rotation_degrees = Vector3(-55.0, 0.0, 0.0)
	camera_rig.add_child(camera)

# ════════════════════════════════════════════════════════════════════════════
# UI overlay
# ════════════════════════════════════════════════════════════════════════════
func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	sel_box              = SelectionBox.new()
	sel_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel_box.visible      = false
	canvas.add_child(sel_box)

	# Gold / supply bar
	hud_label = Label.new()
	hud_label.position = Vector2(10, 10)
	hud_label.add_theme_font_size_override("font_size", 16)
	hud_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	canvas.add_child(hud_label)

	# Context hint line below it
	hint_label = Label.new()
	hint_label.position = Vector2(10, 34)
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color(0.80, 0.80, 0.80))
	canvas.add_child(hint_label)

	# Minimap — bottom-right corner, 160×160
	_minimap          = MinimapPanel.new()
	_minimap.name     = "Minimap"
	_minimap.game_ref = self
	_minimap.size     = Vector2(160.0, 160.0)
	var vp_size := get_viewport().get_visible_rect().size
	_minimap.position     = vp_size - Vector2(170.0, 170.0)
	_minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(_minimap)

func _update_hud() -> void:
	hud_label.text = "Gold: %d   Supply: %d / %d" % [player_gold, player_supply, player_max_supply]
	hint_label.text = _get_hint_text()

func _get_hint_text() -> String:
	# Building placement mode
	if _build_bldg != "":
		var bdata : Dictionary = Data.BUILDINGS.get(_build_bldg, {})
		var bname : String     = bdata.get("name", _build_bldg)
		var bcost : int        = bdata.get("gold_cost", 0)
		return "Placing %s (%dg) — [Left-click] confirm   [ESC] cancel" % [bname, bcost]

	# Build menu open (worker selecting what to construct)
	if _build_menu:
		var available : Array = _get_buildable_buildings()
		if available.is_empty():
			return "No buildings available   [ESC] cancel"
		var text : String = "BUILD:   "
		for i in available.size():
			var bdata : Dictionary = Data.BUILDINGS.get(available[i], {})
			var bname : String     = bdata.get("name", available[i])
			var bcost : int        = bdata.get("gold_cost", 0)
			if i > 0:
				text += "   "
			text += "[%d] %s (%dg)" % [i + 1, bname, bcost]
		return text + "   [ESC] cancel"

	var sel_bldgs := _get_selected_buildings()
	var sel_units := _get_selected_units()

	if not sel_bldgs.is_empty():
		var b      := sel_bldgs[0] as Building
		var bdata  : Dictionary = Data.BUILDINGS.get(b.building_id, {})
		var bname  : String     = bdata.get("name", b.building_id)
		var trains : Array      = bdata.get("trains", [])
		if not b.production_queue.is_empty():
			var pct := int(b.get_progress() * 100.0)
			return "%s — Training: %d%%   queue: %d" % [bname, pct, b.production_queue.size()]
		if trains.is_empty():
			return "%s — nothing to train here" % bname
		var text : String = bname + ":   "
		for i in trains.size():
			var udata : Dictionary = Data.UNITS.get(trains[i], {})
			var uname : String     = udata.get("name", trains[i])
			var ucost : int        = udata.get("gold_cost", 0)
			if i > 0:
				text += "   "
			text += "[%d] %s (%dg)" % [i + 1, uname, ucost]
		return text

	if not sel_units.is_empty():
		var workers := sel_units.filter(func(e): return (e as Unit).unit_type == Unit.UnitType.WORKER)
		if not workers.is_empty():
			return "Worker — [B] build   [Right-click gold] gather   [Right-click enemy] attack"
		return "Unit — [Right-click] move / attack"

	return "[Click/Drag] select   [WASD] pan   [Scroll] zoom"

# ════════════════════════════════════════════════════════════════════════════
# Spawn helpers
# ════════════════════════════════════════════════════════════════════════════
func _spawn_starting_buildings() -> void:
	var fdata   : Dictionary = Data.FACTIONS.get(player_faction, {})
	var bldg_id : String     = fdata.get("main_building", "great_hall")
	var b = BuildingScene.instantiate()
	b.building_id = bldg_id
	b.owner_id    = "player1"
	b.position    = PLAYER_START + Vector3(-4.0, 0.0, -4.0)
	b.production_complete.connect(_on_production_complete)
	add_child(b)   # _ready() fires here, loading supply_provided from Data
	all_buildings.append(b)
	main_building       = b
	player_max_supply  += b.supply_provided

func _spawn_resource_nodes() -> void:
	var node_positions : Array[Vector3] = [
		PLAYER_START + Vector3(14.0,  0.0,  0.0),   # east  (close)
		PLAYER_START + Vector3( 0.0,  0.0, 14.0),   # south (close)
		PLAYER_START + Vector3(14.0,  0.0, 14.0),   # southeast
		Vector3(50.0, 0.0, 44.0),                   # contested mid-north
		Vector3(50.0, 0.0, 56.0),                   # contested mid-south
	]
	for pos in node_positions:
		var rn = ResourceNodeScene.instantiate()
		rn.position = pos
		add_child(rn)
		resource_nodes.append(rn)

func _spawn_starting_units() -> void:
	var fdata      : Dictionary = Data.FACTIONS.get(player_faction, {})
	var worker_id  : String     = fdata.get("worker",       "smallfolk")
	var starter_id : String     = fdata.get("starter_unit", "levy_spearman")

	var worker_offsets : Array[Vector3] = [
		Vector3( 3.0, 0.0,  0.0),
		Vector3(-3.0, 0.0,  0.0),
		Vector3( 0.0, 0.0,  3.0),
	]
	for offset in worker_offsets:
		_spawn_unit(PLAYER_START + offset, worker_id)

	_spawn_unit(PLAYER_START + Vector3(0.0, 0.0, -5.0), starter_id)

func _spawn_unit(pos: Vector3, uid: String) -> void:
	var u = UnitScene.instantiate()
	u.unit_id  = uid
	u.owner_id = "player1"
	u.position = pos
	u.deposited_gold.connect(_on_gold_deposited)
	u.died.connect(_on_unit_died.bind(u))
	add_child(u)   # _ready() fires here, loading all stats from Data
	all_units.append(u)
	player_supply += u.supply_cost

func _spawn_enemy_units() -> void:
	# Small raiding party used as combat targets for Phase 5 (no AI yet)
	var types : Array[String]   = ["raider", "raider", "raider", "giant"]
	var offsets : Array[Vector3] = [
		Vector3(-5.0, 0.0,  2.0),
		Vector3( 0.0, 0.0,  0.0),
		Vector3( 5.0, 0.0,  2.0),
		Vector3( 0.0, 0.0, -6.0),
	]
	for i in types.size():
		_spawn_enemy_unit(ENEMY_START + offsets[i], types[i])

func _spawn_enemy_unit(pos: Vector3, uid: String) -> void:
	var u = UnitScene.instantiate()
	u.unit_id  = uid
	u.owner_id = "player2"
	u.position = pos
	u.died.connect(_on_unit_died.bind(u))
	add_child(u)
	all_units.append(u)

# ════════════════════════════════════════════════════════════════════════════
# Economy signals
# ════════════════════════════════════════════════════════════════════════════
func _on_gold_deposited(amount: int) -> void:
	player_gold += amount

func _on_unit_died(unit: Unit) -> void:
	all_units.erase(unit)
	selected.erase(unit)
	if unit.owner_id == "player1":
		player_supply -= unit.supply_cost

func _on_production_complete(unit_id: String, spawn_pos: Vector3) -> void:
	_spawn_unit(spawn_pos, unit_id)

# ════════════════════════════════════════════════════════════════════════════
# Fog of war
# ════════════════════════════════════════════════════════════════════════════
func _setup_fog() -> void:
	var cell_count : int = FOG_SIZE * FOG_SIZE
	_fog_explored = PackedByteArray()
	_fog_explored.resize(cell_count)
	_fog_explored.fill(0)
	_fog_state = PackedByteArray()
	_fog_state.resize(cell_count)
	_fog_state.fill(0)

	_fog_image = Image.create(FOG_SIZE, FOG_SIZE, false, Image.FORMAT_RGBA8)
	_fog_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	_fog_texture = ImageTexture.create_from_image(_fog_image)

	var mat := StandardMaterial3D.new()
	mat.transparency    = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode    = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter  = BaseMaterial3D.TEXTURE_FILTER_NEAREST   # PS1 blocky cells
	mat.albedo_texture  = _fog_texture
	mat.render_priority = 1

	var plane := PlaneMesh.new()
	plane.size     = Vector2(MAP_SIZE, MAP_SIZE)
	plane.material = mat

	var fog_mesh      := MeshInstance3D.new()
	fog_mesh.name      = "FogOfWar"
	fog_mesh.mesh      = plane
	fog_mesh.position  = Vector3(MAP_SIZE * 0.5, 0.05, MAP_SIZE * 0.5)
	add_child(fog_mesh)

func _update_fog() -> void:
	# Collect player unit positions as Vector2(world_x, world_z)
	var unit_xz : Array[Vector2] = []
	for u_node in all_units:
		var u := u_node as Unit
		if u.owner_id == "player1":
			unit_xz.append(Vector2(u.global_position.x, u.global_position.z))

	var vis_r_sq  : float = VISION_R * VISION_R
	var cell_w    : float = MAP_SIZE / float(FOG_SIZE)
	var changed   : bool  = false

	for py in FOG_SIZE:
		var wz : float = (float(py) + 0.5) * cell_w
		for px in FOG_SIZE:
			var wx  : float = (float(px) + 0.5) * cell_w
			var idx : int   = py * FOG_SIZE + px

			var is_vis : bool = false
			for upos in unit_xz:
				var dx : float = upos.x - wx
				var dz : float = upos.y - wz   # upos.y holds world Z
				if dx * dx + dz * dz < vis_r_sq:
					is_vis = true
					break

			var new_state : int
			if is_vis:
				new_state = 2
				_fog_explored[idx] = 1
			elif _fog_explored[idx] == 1:
				new_state = 1
			else:
				new_state = 0

			if new_state != int(_fog_state[idx]):
				_fog_state[idx] = new_state
				changed = true
				match new_state:
					2: _fog_image.set_pixel(px, py, Color(0.0, 0.0, 0.0, 0.00))
					1: _fog_image.set_pixel(px, py, Color(0.0, 0.0, 0.0, 0.65))
					_: _fog_image.set_pixel(px, py, Color(0.0, 0.0, 0.0, 1.00))

	if changed:
		_fog_texture.update(_fog_image)

	# Hide enemy units that are outside any player unit's vision
	for u_node in all_units:
		var u := u_node as Unit
		if u.owner_id == "player1":
			continue
		u.visible = _is_world_pos_visible(u.global_position)

func _is_world_pos_visible(world_pos: Vector3) -> bool:
	var cell_w : float = MAP_SIZE / float(FOG_SIZE)
	var px     : int   = clamp(int(world_pos.x / cell_w), 0, FOG_SIZE - 1)
	var py     : int   = clamp(int(world_pos.z / cell_w), 0, FOG_SIZE - 1)
	return int(_fog_state[py * FOG_SIZE + px]) == 2

# ════════════════════════════════════════════════════════════════════════════
# Input registration
# ════════════════════════════════════════════════════════════════════════════
func _register_input_actions() -> void:
	var bindings : Dictionary = {
		"cam_left":  [KEY_A, KEY_LEFT],
		"cam_right": [KEY_D, KEY_RIGHT],
		"cam_up":    [KEY_W, KEY_UP],
		"cam_down":  [KEY_S, KEY_DOWN],
	}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode: Key in bindings[action]:
			var ev := InputEventKey.new()
			ev.keycode = keycode
			InputMap.action_add_event(action, ev)

# ════════════════════════════════════════════════════════════════════════════
# Per-frame
# ════════════════════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	_pan_camera(delta)
	if not dragging:
		_edge_scroll(delta)
	_fog_tick += 1
	if _fog_tick >= 8:
		_fog_tick = 0
		_update_fog()
	_ai_tick += 1
	if _ai_tick >= 30:
		_ai_tick = 0
		_update_enemy_ai()
	_update_hud()

func _pan_camera(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_action_pressed("cam_left"):  move.x -= 1.0
	if Input.is_action_pressed("cam_right"): move.x += 1.0
	if Input.is_action_pressed("cam_up"):    move.y -= 1.0
	if Input.is_action_pressed("cam_down"):  move.y += 1.0
	if move != Vector2.ZERO:
		_apply_cam_pan(move, delta)

func _edge_scroll(delta: float) -> void:
	if camera == null:
		return
	var mouse   := get_viewport().get_mouse_position()
	var vp_size := get_viewport().get_visible_rect().size
	var move    := Vector2.ZERO
	if mouse.x < EDGE_MARGIN:                  move.x -= 1.0
	if mouse.x > vp_size.x - EDGE_MARGIN:     move.x += 1.0
	if mouse.y < EDGE_MARGIN:                  move.y -= 1.0
	if mouse.y > vp_size.y - EDGE_MARGIN:     move.y += 1.0
	if move != Vector2.ZERO:
		_apply_cam_pan(move, delta)

func _apply_cam_pan(move: Vector2, delta: float) -> void:
	var cam_right   := camera.global_transform.basis.x.normalized()
	var cam_forward := -camera.global_transform.basis.z
	cam_forward.y   = 0.0
	cam_forward     = cam_forward.normalized()
	var dp := (cam_right * move.x + cam_forward * -move.y) * CAM_PAN_SPEED * delta
	camera_rig.position += dp
	camera_rig.position.x = clamp(camera_rig.position.x, 0.0, MAP_SIZE)
	camera_rig.position.z = clamp(camera_rig.position.z, 0.0, MAP_SIZE)

func _zoom(amount: float) -> void:
	if camera == null:
		return
	var new_y : float = clamp(camera.position.y + amount, CAM_ZOOM_MIN, CAM_ZOOM_MAX)
	var ratio : float = 1.0
	if camera.position.y != 0.0:
		ratio = new_y / camera.position.y
	camera.position.y = new_y
	camera.position.z = clamp(camera.position.z * ratio, CAM_ZOOM_MIN * 0.7, CAM_ZOOM_MAX * 0.7)

# ════════════════════════════════════════════════════════════════════════════
# Input events
# ════════════════════════════════════════════════════════════════════════════
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				drag_start = mb.position
				dragging   = false
			else:
				if _build_bldg != "":
					var world_pos := _raycast_ground(mb.position)
					if world_pos != Vector3.INF:
						_place_building(world_pos, _build_bldg)
					_build_bldg = ""
				elif dragging:
					_finish_box_select(mb.position)
				else:
					_pick_at(mb.position)
				dragging        = false
				sel_box.visible = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_right_click(mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom(-3.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom(3.0)

	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var cur := (event as InputEventMouseMotion).position
			if not dragging and (cur - drag_start).length() > DRAG_THRESHOLD and _build_bldg == "":
				dragging = true
			if dragging:
				sel_box.visible = true
				sel_box.draw_box(drag_start, cur)

	elif event is InputEventKey:
		var ke := event as InputEventKey
		if not ke.pressed:
			return
		match ke.keycode:
			KEY_ESCAPE:
				_deselect_all()
				_build_menu = false
				_build_bldg = ""
			KEY_B:
				_toggle_build_menu()
			KEY_T:
				_try_train_by_slot(0)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
				var slot : int = ke.keycode - KEY_1
				if _build_menu:
					_select_build_slot(slot)
				else:
					_try_train_by_slot(slot)

# ════════════════════════════════════════════════════════════════════════════
# Selection
# ════════════════════════════════════════════════════════════════════════════
func _pick_at(screen_pos: Vector2) -> void:
	_deselect_all()
	var hit = _raycast_layer(screen_pos, 2)
	if hit is Unit and (hit as Unit).owner_id == "player1":
		(hit as Unit).select(true)
		selected.append(hit)
		return
	hit = _raycast_layer(screen_pos, 3)
	if hit is Building:
		selected.append(hit)

func _finish_box_select(end_pos: Vector2) -> void:
	_deselect_all()
	var rect := Rect2(
		Vector2(minf(drag_start.x, end_pos.x), minf(drag_start.y, end_pos.y)),
		Vector2(absf(end_pos.x - drag_start.x), absf(end_pos.y - drag_start.y))
	)
	for u in all_units:
		var unit := u as Unit
		if unit.owner_id != "player1":
			continue
		var screen := camera.unproject_position(unit.global_position + Vector3(0.0, 0.65, 0.0))
		if rect.has_point(screen):
			unit.select(true)
			selected.append(unit)

func _deselect_all() -> void:
	for e in selected:
		if e is Unit:
			(e as Unit).select(false)
	selected.clear()

func _get_selected_units() -> Array:
	return selected.filter(func(e): return e is Unit)

func _get_selected_buildings() -> Array:
	return selected.filter(func(e): return e is Building)

# ════════════════════════════════════════════════════════════════════════════
# Commands
# ════════════════════════════════════════════════════════════════════════════
func _right_click(screen_pos: Vector2) -> void:
	if selected.is_empty():
		return

	# Priority 1 — right-click on enemy unit → attack
	var hit_unit = _raycast_layer(screen_pos, 2)
	if hit_unit is Unit and (hit_unit as Unit).owner_id != "player1":
		var sel_units := _get_selected_units()
		if not sel_units.is_empty():
			for u in sel_units:
				(u as Unit).attack(hit_unit as Unit)
			return

	# Priority 2 — right-click on resource node with workers selected → gather
	var rn = _raycast_layer(screen_pos, 4)
	if rn is ResourceNode and not rn.is_depleted():
		var workers := _get_selected_units().filter(
			func(e): return (e as Unit).unit_type == Unit.UnitType.WORKER
		)
		if not workers.is_empty() and main_building != null:
			for w in workers:
				(w as Unit).gather_from(rn as ResourceNode, main_building)
			return

	# Priority 3 — right-click on ground → move
	var world_pos := _raycast_ground(screen_pos)
	if world_pos == Vector3.INF:
		return
	var units := _get_selected_units()
	var count := units.size()
	for i in count:
		(units[i] as Unit).move_to(world_pos + _formation_offset(i, count))

func _try_train_by_slot(slot: int) -> void:
	for b_node in _get_selected_buildings():
		var building : Building   = b_node as Building
		var bdata    : Dictionary = Data.BUILDINGS.get(building.building_id, {})
		var trains   : Array      = bdata.get("trains", [])
		if slot >= trains.size():
			continue
		var unit_id  : String     = trains[slot]
		var udata    : Dictionary = Data.UNITS.get(unit_id, {})
		var cost     : int        = udata.get("gold_cost", 50)
		if player_gold >= cost:
			if building.enqueue(unit_id):
				player_gold -= cost

func _toggle_build_menu() -> void:
	var workers := _get_selected_units().filter(func(e): return (e as Unit).unit_type == Unit.UnitType.WORKER)
	if workers.is_empty():
		return
	_build_menu = not _build_menu
	_build_bldg = ""

func _select_build_slot(slot: int) -> void:
	var available : Array = _get_buildable_buildings()
	if slot >= available.size():
		return
	_build_bldg = available[slot]
	_build_menu = false

func _get_buildable_buildings() -> Array:
	var result : Array = []
	for bldg_id in Data.BUILDINGS:
		var bdata : Dictionary = Data.BUILDINGS[bldg_id]
		if bdata.get("faction", "") != player_faction:
			continue
		if int(bdata.get("gold_cost", 0)) == 0:
			continue
		result.append(bldg_id)
	return result

func _place_building(world_pos: Vector3, bldg_id: String) -> void:
	var bdata : Dictionary = Data.BUILDINGS.get(bldg_id, {})
	var cost  : int        = bdata.get("gold_cost", 0)
	if player_gold < cost:
		return
	player_gold -= cost
	var b = BuildingScene.instantiate()
	b.building_id = bldg_id
	b.owner_id    = "player1"
	b.position    = Vector3(world_pos.x, 0.0, world_pos.z)
	b.production_complete.connect(_on_production_complete)
	add_child(b)
	all_buildings.append(b)
	player_max_supply += (b as Building).supply_provided
	# Move any selected workers to stand beside the new building
	var workers := _get_selected_units().filter(func(e): return (e as Unit).unit_type == Unit.UnitType.WORKER)
	var sp : Vector3 = (b as Building).get_spawn_pos()
	for w in workers:
		(w as Unit).move_to(sp)

func _update_enemy_ai() -> void:
	for u_node in all_units:
		var enemy := u_node as Unit
		if enemy.owner_id == "player1":
			continue
		# Already chasing or attacking a valid target — leave it
		if (enemy.state == Unit.UnitState.ATTACK_MOVE or enemy.state == Unit.UnitState.ATTACKING) \
				and enemy.attack_target != null and is_instance_valid(enemy.attack_target):
			continue
		# Scan for nearest player unit within aggro radius
		var best   : Unit  = null
		var best_d : float = 28.0
		for t_node in all_units:
			var target := t_node as Unit
			if target.owner_id != "player1":
				continue
			var d : float = enemy.global_position.distance_to(target.global_position)
			if d < best_d:
				best_d = d
				best   = target
		if best != null:
			enemy.attack(best)

# ════════════════════════════════════════════════════════════════════════════
# Raycasting helpers
# ════════════════════════════════════════════════════════════════════════════
func _raycast_layer(screen_pos: Vector2, layer: int) -> Object:
	var space      := get_world_3d().direct_space_state
	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_end    := ray_origin + camera.project_ray_normal(screen_pos) * 500.0
	var query      := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = layer
	var result := space.intersect_ray(query)
	return result["collider"] if result else null

func _raycast_ground(screen_pos: Vector2) -> Vector3:
	var space      := get_world_3d().direct_space_state
	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_end    := ray_origin + camera.project_ray_normal(screen_pos) * 500.0
	var query      := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = 1
	var result := space.intersect_ray(query)
	return result["position"] if result else Vector3.INF

func _formation_offset(index: int, total: int) -> Vector3:
	const SPACING : float = 1.3
	var cols : int   = mini(total, 4)
	var col  : int   = index % cols
	var row  : int   = index / cols
	var cx   : float = float(cols - 1) * 0.5
	return Vector3((float(col) - cx) * SPACING, 0.0, float(row) * SPACING)
