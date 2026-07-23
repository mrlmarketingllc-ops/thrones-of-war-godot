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
			if not u.visible and u.owner_id != game_ref.local_owner:
				continue
			var col : Color = Color(0.25, 0.55, 1.0) if u.owner_id == game_ref.local_owner else Color(1.0, 0.22, 0.22)
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

var _build_menu  : bool   = false   # worker build menu open
var _build_bldg  : String = ""      # building type chosen for placement
var _ai_tick     : int    = 0
var _wave_timer  : float  = 90.0   # seconds until next enemy wave
var _spawn_timer : float  = 45.0   # seconds until next enemy reinforcement

# PvP networking
var is_pvp         : bool                = false
var local_owner    : String              = "player1"
var _enet          : ENetMultiplayerPeer = null
var _net_seq       : int                 = 0
var _p1_seq        : int                 = 100
var _p2_seq        : int                 = 10000
var _net_units     : Dictionary          = {}
var _net_buildings : Dictionary          = {}
var _lobby_layer   : CanvasLayer         = null
var _lobby_status  : Label               = null
var _lobby_ip      : LineEdit            = null

# ════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	_register_input_actions()
	_build_scene()
	_setup_fog()
	_setup_ui()
	_show_lobby()

# ════════════════════════════════════════════════════════════════════════════
# Scene construction
# ════════════════════════════════════════════════════════════════════════════
func _build_scene() -> void:
	_setup_sky()
	_setup_lighting()
	_setup_ground()
	_setup_camera()
	_spawn_terrain_features()

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
# Terrain features — visual only, no unit collision
# ════════════════════════════════════════════════════════════════════════════
func _spawn_terrain_features() -> void:
	_spawn_river()
	_spawn_bridges()
	_spawn_hills()
	_spawn_rocks()
	_spawn_trees()

func _spawn_river() -> void:
	# A river running east–west at z ≈ 38, between the two bases
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.12, 0.30, 0.52, 0.88)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness    = 0.05
	water_mat.metallic     = 0.40
	water_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var water_plane := PlaneMesh.new()
	water_plane.size     = Vector2(MAP_SIZE + 4.0, 8.0)
	water_plane.material = water_mat
	var water_vis := MeshInstance3D.new()
	water_vis.name     = "RiverSurface"
	water_vis.mesh     = water_plane
	water_vis.position = Vector3(MAP_SIZE * 0.5, 0.03, 38.0)
	add_child(water_vis)

	# Muddy riverbanks — thin strips along each shore
	for side in [-1.0, 1.0]:
		var bank_mat := StandardMaterial3D.new()
		bank_mat.albedo_color = Color(0.28, 0.21, 0.12)
		bank_mat.roughness    = 1.0
		var bank_plane := PlaneMesh.new()
		bank_plane.size     = Vector2(MAP_SIZE + 4.0, 1.8)
		bank_plane.material = bank_mat
		var bank_vis := MeshInstance3D.new()
		bank_vis.mesh     = bank_plane
		bank_vis.position = Vector3(MAP_SIZE * 0.5, 0.02, 38.0 + side * 4.8)
		add_child(bank_vis)

	# ── Impassable river walls (layer 5) with bridge gaps ─────────────────────
	# Bridge 1 gap: x = 23..33  (centre x=28)
	# Bridge 2 gap: x = 66..76  (centre x=71)
	var wall_segs : Array = [
		[10.5, 25.0],   # x = -2  → 23
		[49.5, 33.0],   # x = 33  → 66
		[90.0, 28.0],   # x = 76  → 104
	]
	for ws in wall_segs:
		var wc    : float = ws[0]
		var wlen  : float = ws[1]
		var w_shape := BoxShape3D.new()
		w_shape.size = Vector3(wlen, 4.0, 10.0)
		var w_col := CollisionShape3D.new()
		w_col.shape    = w_shape
		w_col.position = Vector3(0.0, 2.0, 0.0)
		var w_body := StaticBody3D.new()
		w_body.collision_layer = 16   # layer 5 — impassable terrain
		w_body.collision_mask  = 0
		w_body.add_child(w_col)
		w_body.position = Vector3(wc, 0.0, 38.0)
		add_child(w_body)

func _spawn_hills() -> void:
	# Pre-placed conical hills with solid collision — units walk up/around them
	# [center_x, center_z, base_radius, height]
	var defs : Array = [
		[25.0, 22.0, 9.0, 3.0],
		[72.0, 20.0, 7.0, 2.5],
		[20.0, 72.0, 8.0, 2.8],
		[78.0, 72.0, 9.0, 3.5],
		[30.0, 53.0, 6.0, 2.0],
		[68.0, 47.0, 7.0, 2.2],
		[50.0, 12.0, 6.0, 1.8],
		[50.0, 88.0, 7.0, 2.5],
	]
	for raw in defs:
		var cx   : float = raw[0]
		var cz   : float = raw[1]
		var brad : float = raw[2]
		var ht   : float = raw[3]

		# Visual cone
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.19, 0.34, 0.13).darkened(randf() * 0.22)
		mat.roughness    = 1.0
		var cone := CylinderMesh.new()
		cone.top_radius    = brad * 0.18
		cone.bottom_radius = brad
		cone.height        = ht
		cone.material      = mat
		var vis := MeshInstance3D.new()
		vis.mesh     = cone
		vis.position = Vector3(0.0, ht * 0.5 + 0.01, 0.0)

		# Solid convex cone collision on layer 1 (ground) — units climb it
		var pts := PackedVector3Array()
		for j in 12:
			var ang : float = float(j) / 12.0 * TAU
			pts.append(Vector3(cos(ang) * brad,        0.01, sin(ang) * brad))
			pts.append(Vector3(cos(ang) * brad * 0.18, ht,   sin(ang) * brad * 0.18))
		pts.append(Vector3(0.0, ht + 0.05, 0.0))   # apex
		var cone_shape := ConvexPolygonShape3D.new()
		cone_shape.points = pts
		var col := CollisionShape3D.new()
		col.shape = cone_shape
		var hill_body := StaticBody3D.new()
		hill_body.collision_layer = 1
		hill_body.collision_mask  = 0
		hill_body.add_child(col)

		var node := Node3D.new()
		node.position = Vector3(cx, 0.0, cz)
		node.add_child(vis)
		node.add_child(hill_body)
		add_child(node)

func _spawn_rocks() -> void:
	var positions : Array[Vector2] = [
		Vector2(42.0, 23.0), Vector2(60.0, 30.0),
		Vector2(15.0, 57.0), Vector2(82.0, 48.0),
		Vector2(55.0, 82.0), Vector2(27.0, 44.0),
		Vector2(64.0, 85.0), Vector2(38.0, 64.0),
	]
	for rp in positions:
		_place_rock_cluster(Vector3(rp.x, 0.01, rp.y))

func _place_rock_cluster(center: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(center.x * 137.0 + center.z * 31.0)
	var cluster := Node3D.new()
	cluster.position = center
	for _i in rng.randi_range(3, 5):
		var sz := Vector3(
			rng.randf_range(0.35, 1.05),
			rng.randf_range(0.28, 0.85),
			rng.randf_range(0.35, 1.00)
		)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(
			rng.randf_range(0.36, 0.52),
			rng.randf_range(0.33, 0.45),
			rng.randf_range(0.28, 0.40)
		)
		mat.roughness = 1.0
		var box := BoxMesh.new()
		box.size     = sz
		box.material = mat
		var rock := MeshInstance3D.new()
		rock.mesh     = box
		rock.position = Vector3(
			rng.randf_range(-1.6, 1.6),
			sz.y * 0.5,
			rng.randf_range(-1.6, 1.6)
		)
		rock.rotation = Vector3(
			rng.randf_range(-0.18, 0.18),
			rng.randf_range(0.0, TAU),
			rng.randf_range(-0.18, 0.18)
		)
		cluster.add_child(rock)
	add_child(cluster)

func _spawn_bridges() -> void:
	# Two stone bridges crossing the river — one left-centre, one right-centre
	for bx in [28.0, 71.0]:
		_place_bridge(bx)

func _place_bridge(bx: float) -> void:
	var node := Node3D.new()
	node.position = Vector3(bx, 0.0, 38.0)

	# Bridge deck — stone-coloured flat platform flush with ground
	var deck_mat := StandardMaterial3D.new()
	deck_mat.albedo_color = Color(0.52, 0.46, 0.38)
	deck_mat.roughness    = 1.0
	var deck := BoxMesh.new()
	deck.size     = Vector3(10.0, 0.30, 8.0)
	deck.material = deck_mat
	var deck_vis := MeshInstance3D.new()
	deck_vis.mesh     = deck
	deck_vis.position = Vector3(0.0, 0.16, 0.0)   # bottom at y=0.01 (above ground, no z-fight)
	node.add_child(deck_vis)

	# Stone abutments (pillars) on east and west ends
	for side in [-1.0, 1.0]:
		var abt_mat := StandardMaterial3D.new()
		abt_mat.albedo_color = Color(0.42, 0.36, 0.28)
		abt_mat.roughness    = 1.0
		var abt := BoxMesh.new()
		abt.size     = Vector3(0.9, 1.2, 9.0)
		abt.material = abt_mat
		var abt_vis := MeshInstance3D.new()
		abt_vis.mesh     = abt
		abt_vis.position = Vector3(side * 5.3, 0.6, 0.0)
		node.add_child(abt_vis)

	# Low guard rails along each river-side edge
	for side in [-1.0, 1.0]:
		var rail_mat := StandardMaterial3D.new()
		rail_mat.albedo_color = Color(0.38, 0.32, 0.26)
		rail_mat.roughness    = 1.0
		var rail := BoxMesh.new()
		rail.size     = Vector3(10.0, 0.45, 0.20)
		rail.material = rail_mat
		var rail_vis := MeshInstance3D.new()
		rail_vis.mesh     = rail
		rail_vis.position = Vector3(0.0, 0.45, side * 4.1)
		node.add_child(rail_vis)

	add_child(node)

func _spawn_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99887   # fixed seed → same forest every run

	# Exclusion zone centres (units: world pos)
	var excl : Array[Vector3] = [
		PLAYER_START,
		ENEMY_START,
		PLAYER_START + Vector3(14.0, 0.0,  0.0),
		PLAYER_START + Vector3( 0.0, 0.0, 14.0),
		PLAYER_START + Vector3(14.0, 0.0, 14.0),
		Vector3(50.0, 0.0, 44.0),
		Vector3(50.0, 0.0, 56.0),
	]

	var placed : int = 0
	var tries  : int = 0
	while placed < 38 and tries < 800:
		tries += 1
		var x : float = rng.randf_range(4.0, 96.0)
		var z : float = rng.randf_range(4.0, 96.0)
		var pos := Vector3(x, 0.01, z)

		# Reject if inside a base / resource zone
		var ok : bool = true
		for ep in excl:
			if pos.distance_to(ep) < 13.0:
				ok = false
				break
		# Reject if in the river band
		if absf(z - 38.0) < 6.0:
			ok = false
		if not ok:
			continue

		_place_tree(pos, rng)
		placed += 1

func _place_tree(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var is_pine : bool  = rng.randf() > 0.38
	var height  : float = rng.randf_range(1.8, 3.2)
	var trunk_r : float = rng.randf_range(0.10, 0.18)
	var crown_r : float = rng.randf_range(0.85, 1.55)

	# Trunk
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(
		rng.randf_range(0.28, 0.40),
		rng.randf_range(0.18, 0.26),
		rng.randf_range(0.08, 0.14)
	)
	trunk_mat.roughness = 1.0
	var trunk_h  : float = height * 0.42
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius    = trunk_r * 0.55
	trunk_mesh.bottom_radius = trunk_r
	trunk_mesh.height        = trunk_h
	trunk_mesh.material      = trunk_mat
	var trunk_vis := MeshInstance3D.new()
	trunk_vis.mesh     = trunk_mesh
	trunk_vis.position = Vector3(0.0, trunk_h * 0.5, 0.0)

	# Crown
	var g : float = rng.randf_range(0.30, 0.52)
	var crown_mat := StandardMaterial3D.new()
	crown_mat.albedo_color = Color(rng.randf_range(0.04, 0.14), g, rng.randf_range(0.04, 0.12))
	crown_mat.roughness    = 1.0
	var crown_vis := MeshInstance3D.new()
	if is_pine:
		var cone := CylinderMesh.new()
		cone.top_radius    = 0.02
		cone.bottom_radius = crown_r
		cone.height        = height * 0.72
		cone.material      = crown_mat
		crown_vis.mesh     = cone
		crown_vis.position = Vector3(0.0, trunk_h + height * 0.72 * 0.5, 0.0)
	else:
		var sphere := SphereMesh.new()
		sphere.radius   = crown_r
		sphere.height   = crown_r * 1.85
		sphere.material = crown_mat
		crown_vis.mesh     = sphere
		crown_vis.position = Vector3(0.0, trunk_h + crown_r * 0.72, 0.0)

	var tree := Node3D.new()
	tree.position  = pos
	tree.rotation.y = rng.randf() * TAU
	tree.add_child(trunk_vis)
	tree.add_child(crown_vis)
	add_child(tree)

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

func _launch_enemy_wave() -> void:
	# Route each enemy through the nearest bridge, then deep into player territory
	var bridge_xs : Array[float] = [28.0, 71.0]
	for u_node in all_units:
		var u := u_node as Unit
		if u.owner_id != "player2":
			continue
		# Pick the bridge whose X is closest to this unit
		var best_bx  : float = bridge_xs[0]
		var best_dx  : float = absf(u.global_position.x - bridge_xs[0])
		for bx in bridge_xs:
			var dx : float = absf(u.global_position.x - bx)
			if dx < best_dx:
				best_dx  = dx
				best_bx  = bx
		# Target: cross the bridge (narrow X) and push into player base
		var target : Vector3 = Vector3(
			best_bx + randf_range(-2.0, 2.0),
			0.0,
			PLAYER_START.z + randf_range(-8.0, 8.0)
		)
		u.move_to(target)

func _try_spawn_enemy() -> void:
	var count : int = 0
	for u_node in all_units:
		if (u_node as Unit).owner_id == "player2":
			count += 1
	if count >= 12:
		return
	var pool : Array[String] = ["raider", "raider", "skinchanger_scout", "thenn_skirmisher", "raider"]
	var uid  : String = pool[randi() % pool.size()]
	_spawn_enemy_unit(
		ENEMY_START + Vector3(randf_range(-7.0, 7.0), 0.0, randf_range(-7.0, 7.0)),
		uid
	)

# ════════════════════════════════════════════════════════════════════════════
# Economy signals
# ════════════════════════════════════════════════════════════════════════════
func _on_gold_deposited(amount: int) -> void:
	player_gold += amount

func _on_unit_died(unit: Unit) -> void:
	all_units.erase(unit)
	selected.erase(unit)
	if unit.owner_id == local_owner:
		player_supply -= unit.supply_cost
	if is_pvp:
		_net_units.erase(unit.net_id)

func _on_production_complete(unit_id: String, spawn_pos: Vector3) -> void:
	if is_pvp:
		var nid : int = _next_net_id()
		_rpc_net_spawn.rpc(local_owner, unit_id, spawn_pos.x, spawn_pos.z, nid)
	else:
		_spawn_unit(spawn_pos, unit_id)

# ════════════════════════════════════════════════════════════════════════════
# Lobby
# ════════════════════════════════════════════════════════════════════════════
func _show_lobby() -> void:
	_lobby_layer        = CanvasLayer.new()
	_lobby_layer.layer  = 10
	add_child(_lobby_layer)

	var panel := Panel.new()
	panel.anchor_left   = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -200.0
	panel.offset_top    = -190.0
	panel.offset_right  = 200.0
	panel.offset_bottom = 190.0
	_lobby_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0.0, 8.0)
	vbox.add_child(pad)

	var title := Label.new()
	title.text = "THRONES OF WAR"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Choose game mode"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(sub)

	_lobby_ip                     = LineEdit.new()
	_lobby_ip.placeholder_text    = "Host IP for Join  (e.g. 192.168.1.5)"
	_lobby_ip.text                = "127.0.0.1"
	_lobby_ip.custom_minimum_size = Vector2(0.0, 36.0)
	vbox.add_child(_lobby_ip)

	var btn_host := Button.new()
	btn_host.text                = "Host Game (LAN)"
	btn_host.custom_minimum_size = Vector2(0.0, 40.0)
	btn_host.pressed.connect(_host_game)
	vbox.add_child(btn_host)

	var btn_join := Button.new()
	btn_join.text                = "Join Game"
	btn_join.custom_minimum_size = Vector2(0.0, 40.0)
	btn_join.pressed.connect(_join_game)
	vbox.add_child(btn_join)

	vbox.add_child(HSeparator.new())

	var btn_solo := Button.new()
	btn_solo.text                = "Play vs AI"
	btn_solo.custom_minimum_size = Vector2(0.0, 40.0)
	btn_solo.pressed.connect(_begin_solo)
	vbox.add_child(btn_solo)

	_lobby_status                      = Label.new()
	_lobby_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(_lobby_status)

func _host_game() -> void:
	_enet = ENetMultiplayerPeer.new()
	var err : int = _enet.create_server(7777, 2)
	if err != OK:
		_lobby_status.text = "Failed to open port 7777"
		return
	multiplayer.multiplayer_peer = _enet
	multiplayer.peer_connected.connect(_on_peer_connected)
	_lobby_status.text = "Waiting for opponent on port 7777..."

func _join_game() -> void:
	var ip : String = _lobby_ip.text.strip_edges()
	_enet = ENetMultiplayerPeer.new()
	var err : int = _enet.create_client(ip, 7777)
	if err != OK:
		_lobby_status.text = "Failed to connect to " + ip
		return
	multiplayer.multiplayer_peer = _enet
	multiplayer.connected_to_server.connect(_on_joined_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	local_owner    = "player2"
	player_faction = "wildlings"
	_lobby_status.text = "Connecting to " + ip + "..."

func _on_peer_connected(_id: int) -> void:
	_lobby_status.text = "Opponent connected!  Starting..."
	await get_tree().process_frame
	_rpc_begin_pvp.rpc()

func _on_joined_server() -> void:
	_lobby_status.text = "Connected — waiting for host..."

func _on_connection_failed() -> void:
	_lobby_status.text = "Connection failed."

func _begin_solo() -> void:
	_close_lobby()
	_spawn_starting_buildings()
	_spawn_resource_nodes()
	_spawn_starting_units()
	_spawn_enemy_units()

func _close_lobby() -> void:
	if _lobby_layer != null:
		_lobby_layer.queue_free()
		_lobby_layer = null

# ════════════════════════════════════════════════════════════════════════════
# PvP game start
# ════════════════════════════════════════════════════════════════════════════
@rpc("authority", "call_local", "reliable")
func _rpc_begin_pvp() -> void:
	is_pvp = true
	if multiplayer.get_unique_id() != 1:
		local_owner    = "player2"
		player_faction = "wildlings"
		camera_rig.position = ENEMY_START
	_close_lobby()
	_pvp_spawn_all()

func _pvp_spawn_all() -> void:
	_spawn_resource_nodes()
	_pvp_spawn_building(PLAYER_START + Vector3(-4.0, 0.0, -4.0), "great_hall",     "player1")
	_pvp_spawn_unit(PLAYER_START + Vector3( 3.0, 0.0,  0.0), "smallfolk",          "player1")
	_pvp_spawn_unit(PLAYER_START + Vector3(-3.0, 0.0,  0.0), "smallfolk",          "player1")
	_pvp_spawn_unit(PLAYER_START + Vector3( 0.0, 0.0,  3.0), "smallfolk",          "player1")
	_pvp_spawn_unit(PLAYER_START + Vector3( 0.0, 0.0, -5.0), "levy_spearman",      "player1")
	_pvp_spawn_building(ENEMY_START + Vector3(-4.0, 0.0, -4.0), "great_tent",      "player2")
	_pvp_spawn_unit(ENEMY_START + Vector3( 3.0, 0.0,  0.0), "forager",             "player2")
	_pvp_spawn_unit(ENEMY_START + Vector3(-3.0, 0.0,  0.0), "forager",             "player2")
	_pvp_spawn_unit(ENEMY_START + Vector3( 0.0, 0.0,  3.0), "forager",             "player2")
	_pvp_spawn_unit(ENEMY_START + Vector3( 0.0, 0.0, -5.0), "raider",              "player2")

func _pvp_spawn_building(pos: Vector3, bldg_id: String, owner: String) -> void:
	_net_seq += 1
	var b = BuildingScene.instantiate()
	b.building_id = bldg_id
	b.owner_id    = owner
	b.net_id      = _net_seq
	b.position    = pos
	if owner == local_owner:
		b.production_complete.connect(_on_production_complete)
	add_child(b)
	all_buildings.append(b)
	_net_buildings[_net_seq] = b
	if owner == local_owner:
		main_building      = b
		player_max_supply += (b as Building).supply_provided

func _pvp_spawn_unit(pos: Vector3, uid: String, owner: String) -> void:
	_net_seq += 1
	var u = UnitScene.instantiate()
	u.unit_id  = uid
	u.owner_id = owner
	u.net_id   = _net_seq
	u.position = pos
	if owner == local_owner:
		u.deposited_gold.connect(_on_gold_deposited)
	u.died.connect(_on_unit_died.bind(u))
	add_child(u)
	all_units.append(u)
	_net_units[_net_seq] = u
	if owner == local_owner:
		player_supply += u.supply_cost

func _next_net_id() -> int:
	if local_owner == "player1":
		_p1_seq += 1
		return _p1_seq
	else:
		_p2_seq += 1
		return _p2_seq

# ════════════════════════════════════════════════════════════════════════════
# RPC commands
# ════════════════════════════════════════════════════════════════════════════
@rpc("any_peer", "call_local", "reliable")
func _rpc_cmd_move(nid: int, tx: float, tz: float) -> void:
	var u : Unit = _net_units.get(nid) as Unit
	if u == null or not is_instance_valid(u):
		return
	u.move_to(Vector3(tx, 0.0, tz))

@rpc("any_peer", "call_local", "reliable")
func _rpc_cmd_attack(attacker_nid: int, target_nid: int) -> void:
	var attacker : Unit = _net_units.get(attacker_nid) as Unit
	var target   : Unit = _net_units.get(target_nid)   as Unit
	if attacker == null or not is_instance_valid(attacker):
		return
	if target == null or not is_instance_valid(target):
		return
	attacker.attack(target)

@rpc("any_peer", "call_local", "reliable")
func _rpc_cmd_gather(worker_nid: int, rn_idx: int, deposit_nid: int) -> void:
	var worker  : Unit     = _net_units.get(worker_nid)      as Unit
	var deposit : Building = _net_buildings.get(deposit_nid) as Building
	if worker == null or not is_instance_valid(worker):
		return
	if deposit == null or not is_instance_valid(deposit):
		return
	if rn_idx < 0 or rn_idx >= resource_nodes.size():
		return
	worker.gather_from(resource_nodes[rn_idx] as ResourceNode, deposit)

@rpc("any_peer", "call_local", "reliable")
func _rpc_net_spawn(owner: String, uid: String, px: float, pz: float, nid: int) -> void:
	var u = UnitScene.instantiate()
	u.unit_id  = uid
	u.owner_id = owner
	u.net_id   = nid
	u.position = Vector3(px, 0.0, pz)
	if owner == local_owner:
		u.deposited_gold.connect(_on_gold_deposited)
	u.died.connect(_on_unit_died.bind(u))
	add_child(u)
	all_units.append(u)
	_net_units[nid] = u
	if owner == local_owner:
		player_supply += u.supply_cost

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

	# ShaderMaterial with blend_mix + depth_test_disabled so fog draws over
	# hills and trees regardless of their height above the y=0.05 plane.
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode blend_mix, unshaded, cull_disabled, depth_test_disabled; uniform sampler2D fog_tex : filter_nearest; void fragment() { vec4 c = texture(fog_tex, UV); ALBEDO = vec3(0.0, 0.0, 0.0); ALPHA = c.a; }"
	var mat := ShaderMaterial.new()
	mat.shader          = shader
	mat.render_priority = 2
	mat.set_shader_parameter("fog_tex", _fog_texture)

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
		if u.owner_id == local_owner:
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
		if u.owner_id == local_owner:
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
	if not is_pvp:
		_ai_tick += 1
		if _ai_tick >= 30:
			_ai_tick = 0
			_update_enemy_ai()
		_wave_timer -= delta
		if _wave_timer <= 0.0:
			_wave_timer = 90.0
			_launch_enemy_wave()
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = 45.0
			_try_spawn_enemy()
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
	if hit is Unit and (hit as Unit).owner_id == local_owner:
		(hit as Unit).select(true)
		selected.append(hit)
		return
	hit = _raycast_layer(screen_pos, 3)
	if hit is Building and (hit as Building).owner_id == local_owner:
		selected.append(hit)

func _finish_box_select(end_pos: Vector2) -> void:
	_deselect_all()
	var rect := Rect2(
		Vector2(minf(drag_start.x, end_pos.x), minf(drag_start.y, end_pos.y)),
		Vector2(absf(end_pos.x - drag_start.x), absf(end_pos.y - drag_start.y))
	)
	for u in all_units:
		var unit := u as Unit
		if unit.owner_id != local_owner:
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
	if hit_unit is Unit and (hit_unit as Unit).owner_id != local_owner:
		var sel_units := _get_selected_units()
		if not sel_units.is_empty():
			for u in sel_units:
				if is_pvp:
					_rpc_cmd_attack.rpc((u as Unit).net_id, (hit_unit as Unit).net_id)
				else:
					(u as Unit).attack(hit_unit as Unit)
			return

	# Priority 2 — right-click on resource node with workers selected → gather
	var rn = _raycast_layer(screen_pos, 4)
	if rn is ResourceNode and not (rn as ResourceNode).is_depleted():
		var workers := _get_selected_units().filter(
			func(e): return (e as Unit).unit_type == Unit.UnitType.WORKER
		)
		if not workers.is_empty() and main_building != null:
			for w in workers:
				if is_pvp:
					var rn_idx : int = resource_nodes.find(rn)
					_rpc_cmd_gather.rpc((w as Unit).net_id, rn_idx, main_building.net_id)
				else:
					(w as Unit).gather_from(rn as ResourceNode, main_building)
			return

	# Priority 3 — right-click on ground → move
	var world_pos := _raycast_ground(screen_pos)
	if world_pos == Vector3.INF:
		return
	var units := _get_selected_units()
	var count := units.size()
	for i in count:
		var offset : Vector3 = _formation_offset(i, count)
		var target : Vector3 = world_pos + offset
		if is_pvp:
			_rpc_cmd_move.rpc((units[i] as Unit).net_id, target.x, target.z)
		else:
			(units[i] as Unit).move_to(target)

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
	if is_pvp:
		return
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
