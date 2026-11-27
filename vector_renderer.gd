extends Node3D
## Hull Down — VECTOR mode renderer.
## Draws the world state owned by main.gd as phosphor line work:
## a dim ground grid, box and pyramid obstacles, a jagged mountain
## ring on the horizon (static mesh), plus per-frame dynamic lines —
## enemy tanks, cannon tracers and impact bursts. Everything is
## ImmediateMesh line pairs with unshaded materials. The future
## 3D-model renderer will sit beside this one and read the same state.

var _bright: StandardMaterial3D
var _dim: StandardMaterial3D
var _amber: StandardMaterial3D
var _enemies_ref: Array = []
var _shells_ref: Array = []
var _tracers: Array[Dictionary] = [] # {from, to, ttl, max, amber}
var _bursts: Array[Dictionary] = [] # {pos, ttl, max, size}
var _dyn_green: ImmediateMesh
var _dyn_amber: ImmediateMesh
var _obst_inst: MeshInstance3D
var _mountain_inst: MeshInstance3D


func _ready() -> void:
	_bright = StandardMaterial3D.new()
	_bright.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bright.albedo_color = Color(0.25, 1.0, 0.35)
	_dim = StandardMaterial3D.new()
	_dim.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dim.albedo_color = Color(0.02, 0.28, 0.08)
	_amber = StandardMaterial3D.new()
	_amber.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_amber.albedo_color = Color(1.0, 0.45, 0.15)
	_dyn_green = ImmediateMesh.new()
	var gi := MeshInstance3D.new()
	gi.mesh = _dyn_green
	gi.material_override = _bright
	add_child(gi)
	_dyn_amber = ImmediateMesh.new()
	var ai := MeshInstance3D.new()
	ai.mesh = _dyn_amber
	ai.material_override = _amber
	add_child(ai)


func set_enemies(enemies: Array) -> void:
	_enemies_ref = enemies


func set_shells(shells: Array) -> void:
	_shells_ref = shells


## Scenery only: the mountain ring and the ground grid are endless —
## follow() keeps them centred on the player, so the plain never ends.
## Obstacles arrive separately through rebuild_obstacles().
func build_world() -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_mountains(mesh)
	mesh.surface_end()
	_mountain_inst = MeshInstance3D.new()
	_mountain_inst.mesh = mesh
	_mountain_inst.material_override = _bright
	add_child(_mountain_inst)

	_obst_inst = MeshInstance3D.new()
	_obst_inst.material_override = _bright
	add_child(_obst_inst)


func rebuild_obstacles(obstacles: Array) -> void:
	var mesh := ImmediateMesh.new()
	if not obstacles.is_empty():
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for ob in obstacles:
			if ob["kind"] == "box":
				_box(mesh, ob["pos"], ob["size"])
			if ob["kind"] == "pyramid":
				_pyramid(mesh, ob["pos"], ob["size"])
		mesh.surface_end()
	_obst_inst.mesh = mesh


func follow(player_pos: Vector3) -> void:
	if _mountain_inst:
		_mountain_inst.position = Vector3(player_pos.x, 0, player_pos.z)


func add_tracer(from: Vector3, to: Vector3, amber: bool) -> void:
	_tracers.append({"from": from, "to": to, "ttl": 0.16, "max": 0.16, "amber": amber})


func add_burst(pos: Vector3, size: float) -> void:
	_bursts.append({"pos": pos, "ttl": 0.3, "max": 0.3, "size": size})


## Called by main every frame; ages effects and rebuilds dynamic lines.
func update_enemies() -> void:
	pass # kept as main's per-frame hook; the work happens in _process


func _process(delta: float) -> void:
	_dyn_green.clear_surfaces()
	_dyn_amber.clear_surfaces()

	# Enemy tanks, player tracers/shells and all bursts burn green.
	# (An ImmediateMesh surface with zero vertices is an error, so the
	# whole surface is skipped on frames where nothing is green.)
	var any_green := not _enemies_ref.is_empty() or not _bursts.is_empty()
	if not any_green:
		for t in _tracers:
			if not bool(t["amber"]):
				any_green = true
	if not any_green:
		for sh in _shells_ref:
			if bool(sh["player"]):
				any_green = true
	if any_green:
		_dyn_green.surface_begin(Mesh.PRIMITIVE_LINES)
		for e in _enemies_ref:
			_tank(_dyn_green, e["pos"], float(e["heading"]))
		for t in _tracers:
			if not bool(t["amber"]):
				_dyn_green.surface_add_vertex(t["from"])
				_dyn_green.surface_add_vertex(t["to"])
		for b in _bursts:
			_burst_lines(_dyn_green, b)
		for sh in _shells_ref:
			if bool(sh["player"]):
				var p: Vector3 = sh["pos"]
				var v: Vector3 = sh["vel"]
				_dyn_green.surface_add_vertex(p)
				_dyn_green.surface_add_vertex(p - v.normalized() * 1.6)
		_dyn_green.surface_end()

	# Enemy tracers and shells burn amber so danger reads at a glance.
	var any_amber := false
	for t in _tracers:
		if bool(t["amber"]):
			if not any_amber:
				_dyn_amber.surface_begin(Mesh.PRIMITIVE_LINES)
				any_amber = true
			_dyn_amber.surface_add_vertex(t["from"])
			_dyn_amber.surface_add_vertex(t["to"])
	for sh in _shells_ref:
		if not bool(sh["player"]):
			if not any_amber:
				_dyn_amber.surface_begin(Mesh.PRIMITIVE_LINES)
				any_amber = true
			var p: Vector3 = sh["pos"]
			var v: Vector3 = sh["vel"]
			_dyn_amber.surface_add_vertex(p)
			_dyn_amber.surface_add_vertex(p - v.normalized() * 1.6)
	if any_amber:
		_dyn_amber.surface_end()

	# Age effects.
	for i in range(_tracers.size() - 1, -1, -1):
		_tracers[i]["ttl"] = float(_tracers[i]["ttl"]) - delta
		if float(_tracers[i]["ttl"]) <= 0.0:
			_tracers.remove_at(i)
	for i in range(_bursts.size() - 1, -1, -1):
		_bursts[i]["ttl"] = float(_bursts[i]["ttl"]) - delta
		if float(_bursts[i]["ttl"]) <= 0.0:
			_bursts.remove_at(i)


func _tank(mesh: ImmediateMesh, pos: Vector3, h: float) -> void:
	# A low hull, a turret, and a barrel — read as a tank in 14 lines.
	var local := [
		# hull: bottom rectangle, top rectangle, uprights — squat and
		# wide like the original's tank, not long and narrow
		Vector3(-1.45, 0.15, -1.05), Vector3(1.45, 0.15, -1.05), Vector3(1.45, 0.15, 1.05), Vector3(-1.45, 0.15, 1.05),
		Vector3(-1.45, 0.8, -1.05), Vector3(1.45, 0.8, -1.05), Vector3(1.45, 0.8, 1.05), Vector3(-1.45, 0.8, 1.05),
		# turret
		Vector3(-0.5, 0.8, -0.3), Vector3(0.5, 0.8, -0.3), Vector3(0.5, 0.8, 0.6), Vector3(-0.5, 0.8, 0.6),
		Vector3(-0.5, 1.25, -0.3), Vector3(0.5, 1.25, -0.3), Vector3(0.5, 1.25, 0.6), Vector3(-0.5, 1.25, 0.6),
	]
	var edges := [
		[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4],
		[0, 4], [1, 5], [2, 6], [3, 7],
		[8, 9], [9, 10], [10, 11], [11, 8], [12, 13], [13, 14], [14, 15], [15, 12],
		[8, 12], [9, 13], [10, 14], [11, 15],
	]
	for e in edges:
		mesh.surface_add_vertex(_to_world(local[e[0]], pos, h))
		mesh.surface_add_vertex(_to_world(local[e[1]], pos, h))
	# Barrel: from the turret's front face, forward.
	mesh.surface_add_vertex(_to_world(Vector3(0, 1.05, -0.3), pos, h))
	mesh.surface_add_vertex(_to_world(Vector3(0, 1.05, -2.1), pos, h))


func _to_world(v: Vector3, pos: Vector3, h: float) -> Vector3:
	return pos + Vector3(v.x * cos(h) + v.z * sin(h), v.y, -v.x * sin(h) + v.z * cos(h))


func _burst_lines(mesh: ImmediateMesh, b: Dictionary) -> void:
	var frac := 1.0 - float(b["ttl"]) / float(b["max"])
	var r := float(b["size"]) * (0.3 + frac * 0.9)
	var c: Vector3 = b["pos"]
	var dirs := [
		Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1),
		Vector3(0.7, 0.7, 0), Vector3(-0.7, 0.7, 0), Vector3(0, 0.8, 0.7), Vector3(0, 0.8, -0.7),
	]
	for d in dirs:
		mesh.surface_add_vertex(c)
		mesh.surface_add_vertex(c + d * r)


func _box(mesh: ImmediateMesh, c: Vector3, s: Vector3) -> void:
	var hx := s.x * 0.5
	var hz := s.z * 0.5
	var h := s.y
	var corners := [
		Vector3(c.x - hx, 0, c.z - hz), Vector3(c.x + hx, 0, c.z - hz),
		Vector3(c.x + hx, 0, c.z + hz), Vector3(c.x - hx, 0, c.z + hz),
		Vector3(c.x - hx, h, c.z - hz), Vector3(c.x + hx, h, c.z - hz),
		Vector3(c.x + hx, h, c.z + hz), Vector3(c.x - hx, h, c.z + hz),
	]
	var edges := [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]]
	for e in edges:
		mesh.surface_add_vertex(corners[e[0]])
		mesh.surface_add_vertex(corners[e[1]])


func _pyramid(mesh: ImmediateMesh, c: Vector3, s: Vector3) -> void:
	var hx := s.x * 0.5
	var apex := Vector3(c.x, s.y, c.z)
	var base := [
		Vector3(c.x - hx, 0, c.z - hx), Vector3(c.x + hx, 0, c.z - hx),
		Vector3(c.x + hx, 0, c.z + hx), Vector3(c.x - hx, 0, c.z + hx),
	]
	for k in 4:
		mesh.surface_add_vertex(base[k])
		mesh.surface_add_vertex(base[(k + 1) % 4])
		mesh.surface_add_vertex(base[k])
		mesh.surface_add_vertex(apex)


func _mountains(mesh: ImmediateMesh) -> void:
	var radius := 190.0
	var count := 72
	var prev := Vector3.ZERO
	for k in count + 1:
		var a := TAU * float(k) / float(count)
		var raw: float = sin(float(k) * 12.9898) * 43758.5453
		var n: float = raw - floor(raw)
		var p := Vector3(sin(a) * radius, 1.2 + n * 3.4, cos(a) * radius)
		if k != 0:
			mesh.surface_add_vertex(prev)
			mesh.surface_add_vertex(p)
		prev = p
	for k in count:
		var a1 := TAU * float(k) / float(count)
		var a2 := TAU * float(k + 1) / float(count)
		mesh.surface_add_vertex(Vector3(sin(a1) * radius, 0.05, cos(a1) * radius))
		mesh.surface_add_vertex(Vector3(sin(a2) * radius, 0.05, cos(a2) * radius))
	# Crescent moon: a circle with a second, offset circle inside it —
	# exactly how the vector original draws it.
	_circle(mesh, Vector3(-70, 31, -176), 6.5)
	_circle(mesh, Vector3(-67.4, 32.0, -176), 5.2)


func _circle(mesh: ImmediateMesh, centre: Vector3, r: float) -> void:
	var segs := 24
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		mesh.surface_add_vertex(centre + Vector3(cos(a0) * r, sin(a0) * r, 0))
		mesh.surface_add_vertex(centre + Vector3(cos(a1) * r, sin(a1) * r, 0))
