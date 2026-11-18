extends Node3D
## Hull Down — VECTOR mode renderer.
## Draws the world state owned by main.gd as bright green line work:
## a dim ground grid, box and pyramid obstacles, and a jagged mountain
## ring on the horizon. Everything is ImmediateMesh line pairs with an
## unshaded material — the closest a raster screen gets to the 1980
## vector display. The future 3D-model renderer will sit beside this
## one and read the same state; neither touches the game logic.

var _bright: StandardMaterial3D
var _dim: StandardMaterial3D
var _tracer_mesh: ImmediateMesh
var _tracer_instance: MeshInstance3D


func _ready() -> void:
	_bright = StandardMaterial3D.new()
	_bright.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bright.albedo_color = Color(0.25, 1.0, 0.35)
	_dim = StandardMaterial3D.new()
	_dim.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dim.albedo_color = Color(0.02, 0.28, 0.08)
	_tracer_mesh = ImmediateMesh.new()
	_tracer_instance = MeshInstance3D.new()
	_tracer_instance.mesh = _tracer_mesh
	_tracer_instance.material_override = _bright
	add_child(_tracer_instance)


func build_world(obstacles: Array) -> void:
	# Obstacles + mountains in the bright mesh.
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for ob in obstacles:
		if ob["kind"] == "box":
			_box(mesh, ob["pos"], ob["size"])
		else:
			_pyramid(mesh, ob["pos"], ob["size"])
	_mountains(mesh)
	mesh.surface_end()
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = _bright
	add_child(inst)

	# Ground grid in the dim mesh — sells the sense of motion.
	var grid := ImmediateMesh.new()
	grid.surface_begin(Mesh.PRIMITIVE_LINES)
	var ext := 120
	var step := 20
	var i := -ext
	while i <= ext:
		grid.surface_add_vertex(Vector3(i, 0.02, -ext))
		grid.surface_add_vertex(Vector3(i, 0.02, ext))
		grid.surface_add_vertex(Vector3(-ext, 0.02, i))
		grid.surface_add_vertex(Vector3(ext, 0.02, i))
		i += step
	grid.surface_end()
	var ginst := MeshInstance3D.new()
	ginst.mesh = grid
	ginst.material_override = _dim
	add_child(ginst)


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
	# A closed jagged ring at the horizon, deterministic heights.
	var radius := 190.0
	var count := 72
	var prev := Vector3.ZERO
	for k in count + 1:
		var a := TAU * float(k) / float(count)
		var raw: float = sin(float(k) * 12.9898) * 43758.5453
		var n: float = raw - floor(raw)
		var p := Vector3(sin(a) * radius, 4.0 + n * 13.0, cos(a) * radius)
		if k != 0:
			mesh.surface_add_vertex(prev)
			mesh.surface_add_vertex(p)
		prev = p
	# A horizon ring at ground level, so the peaks sit on a horizon.
	for k in count:
		var a1 := TAU * float(k) / float(count)
		var a2 := TAU * float(k + 1) / float(count)
		mesh.surface_add_vertex(Vector3(sin(a1) * radius, 0.05, cos(a1) * radius))
		mesh.surface_add_vertex(Vector3(sin(a2) * radius, 0.05, cos(a2) * radius))


func show_tracer(from: Vector3, to: Vector3) -> void:
	_tracer_mesh.clear_surfaces()
	_tracer_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_tracer_mesh.surface_add_vertex(from)
	_tracer_mesh.surface_add_vertex(to)
	_tracer_mesh.surface_end()


func clear_tracer() -> void:
	_tracer_mesh.clear_surfaces()
