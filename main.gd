extends Node3D
## Hull Down — game logic (renderer-agnostic).
## This script owns the world state: the player's tank, the obstacles,
## movement, collision and the cannon. It knows nothing about how the
## world is drawn. vector_renderer.gd reads this state and draws the
## vector mode; the future 3D-model mode will read the same state.
##
## Controls (laptop): W/S or Up/Down drive, A/D or Left/Right turn,
## Space fires, F11 toggles fullscreen. Touch controls come later.

const WORLD_RADIUS := 115.0
const TANK_RADIUS := 1.3
const MOVE_SPEED := 11.0
const TURN_SPEED := 1.6 # radians per second
const FIRE_RANGE := 140.0
const FIRE_COOLDOWN := 0.35

var heading := 0.0 # 0 faces -Z; rotation.y of the tank
var speed_now := 0.0
var fire_cooldown := 0.0
var tracer_time := 0.0

# The world. kind: "box" or "pyramid". pos is the centre on the ground
# plane; size is footprint/depth for boxes (x, height, z); for pyramids
# size.x is the base width and size.y the height.
var obstacles: Array[Dictionary] = [
	{"kind": "box", "pos": Vector3(-4.5, 0, -6), "size": Vector3(2, 2, 2)},
	{"kind": "box", "pos": Vector3(3.5, 0, -11), "size": Vector3(2, 3, 2)},
	{"kind": "pyramid", "pos": Vector3(0.5, 0, -19), "size": Vector3(4, 3, 4)},
	{"kind": "box", "pos": Vector3(-11, 0, -16), "size": Vector3(3, 2, 3)},
	{"kind": "pyramid", "pos": Vector3(10, 0, -24), "size": Vector3(5, 4, 5)},
	{"kind": "box", "pos": Vector3(-7, 0, -31), "size": Vector3(2, 4, 2)},
	{"kind": "box", "pos": Vector3(16, 0, -8), "size": Vector3(2, 2, 2)},
	{"kind": "pyramid", "pos": Vector3(-18, 0, -34), "size": Vector3(6, 4, 6)},
	{"kind": "box", "pos": Vector3(7, 0, -40), "size": Vector3(3, 3, 3)},
	{"kind": "box", "pos": Vector3(-2, 0, 10), "size": Vector3(2, 2, 2)},
	{"kind": "pyramid", "pos": Vector3(13, 0, 14), "size": Vector3(4, 3, 4)},
	{"kind": "box", "pos": Vector3(-13, 0, 7), "size": Vector3(2, 2, 2)},
]

@onready var tank: Node3D = $Tank
@onready var camera: Camera3D = $Tank/Camera3D
@onready var renderer: Node3D = $VectorWorld
@onready var status: Label = $HUD/Status
@onready var vector_btn: Button = $HUD/Options/VectorBtn
@onready var model_btn: Button = $HUD/Options/ModelBtn
@onready var full_btn: Button = $HUD/Options/FullBtn


func _ready() -> void:
	renderer.build_world(obstacles)
	vector_btn.disabled = true # the active mode: shown, not clickable
	model_btn.disabled = true # Adam's pin: 3D option disabled until populated
	full_btn.pressed.connect(toggle_fullscreen)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			toggle_fullscreen()


func toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _process(delta: float) -> void:
	# --- turning ---
	var turn := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		turn += 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		turn -= 1.0
	heading += turn * TURN_SPEED * delta

	# --- driving ---
	var drive := 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		drive += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		drive -= 1.0
	speed_now = drive * MOVE_SPEED
	var forward := Vector3(-sin(heading), 0, -cos(heading))
	var pos := tank.position + forward * speed_now * delta

	# Keep the tank on the plain.
	if Vector2(pos.x, pos.z).length() > WORLD_RADIUS:
		var clamped := Vector2(pos.x, pos.z).limit_length(WORLD_RADIUS)
		pos.x = clamped.x
		pos.z = clamped.y

	tank.position = _resolve_collisions(pos)
	tank.rotation.y = heading

	# --- cannon ---
	fire_cooldown = maxf(fire_cooldown - delta, 0.0)
	if Input.is_physical_key_pressed(KEY_SPACE) and fire_cooldown <= 0.0:
		_fire()
	if tracer_time > 0.0:
		tracer_time -= delta
		if tracer_time <= 0.0:
			renderer.clear_tracer()

	# --- HUD ---
	var compass := int(round(rad_to_deg(-heading))) % 360
	if compass < 0:
		compass += 360
	status.text = "HDG %03d   SPD %+.0f   VECTOR MODE   [W/S drive · A/D turn · SPACE fire · F11 fullscreen]" % [compass, speed_now]


func _resolve_collisions(pos: Vector3) -> Vector3:
	for ob in obstacles:
		var c: Vector3 = ob["pos"]
		var s: Vector3 = ob["size"]
		var hx := s.x * 0.5
		var hz := (s.z if ob["kind"] == "box" else s.x) * 0.5
		var closest := Vector3(clampf(pos.x, c.x - hx, c.x + hx), 0, clampf(pos.z, c.z - hz, c.z + hz))
		var diff := Vector2(pos.x - closest.x, pos.z - closest.z)
		var dist := diff.length()
		if dist < TANK_RADIUS:
			if dist > 0.001:
				var pushed := Vector2(closest.x, closest.z) + diff.normalized() * TANK_RADIUS
				pos.x = pushed.x
				pos.z = pushed.y
			else:
				pos.x = c.x + hx + TANK_RADIUS
	return pos


func _fire() -> void:
	fire_cooldown = FIRE_COOLDOWN
	tracer_time = 0.09
	var origin := camera.global_position
	var dir := -camera.global_transform.basis.z
	var best := FIRE_RANGE
	for ob in obstacles:
		var t := _ray_aabb(origin, dir, ob)
		if t > 0.0 and t < best:
			best = t
	renderer.show_tracer(origin + dir * 1.5, origin + dir * best)


# Slab-method ray vs an obstacle's 3D bounding box. Returns distance or -1.
func _ray_aabb(origin: Vector3, dir: Vector3, ob: Dictionary) -> float:
	var s: Vector3 = ob["size"]
	var depth := s.z if ob["kind"] == "box" else s.x
	var bmin := Vector3(ob["pos"].x - s.x * 0.5, 0.0, ob["pos"].z - depth * 0.5)
	var bmax := Vector3(ob["pos"].x + s.x * 0.5, s.y, ob["pos"].z + depth * 0.5)
	var tmin := 0.0
	var tmax := FIRE_RANGE
	var o := [origin.x, origin.y, origin.z]
	var d := [dir.x, dir.y, dir.z]
	var lo := [bmin.x, bmin.y, bmin.z]
	var hi := [bmax.x, bmax.y, bmax.z]
	for i in 3:
		if absf(d[i]) < 0.0001:
			if o[i] < lo[i] or o[i] > hi[i]:
				return -1.0
		else:
			var t1: float = (lo[i] - o[i]) / d[i]
			var t2: float = (hi[i] - o[i]) / d[i]
			if t1 > t2:
				var tmp: float = t1
				t1 = t2
				t2 = tmp
			tmin = maxf(tmin, t1)
			tmax = minf(tmax, t2)
			if tmin > tmax:
				return -1.0
	return tmin
