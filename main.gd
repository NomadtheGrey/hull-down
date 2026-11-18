extends Node3D
## Hull Down — game logic (renderer-agnostic).
## Owns all world state: the player's tank, obstacles, bot enemies,
## movement, collision, the cannon, score and lives. It knows nothing
## about how the world is drawn: vector_renderer.gd draws this state
## as lines today; the future 3D-model mode reads the same state.
##
## Controls: W/S or Up/Down drive, A/D or Left/Right turn, Space or
## left mouse button fires, F11 toggles fullscreen.

const WORLD_RADIUS := 115.0
const TANK_RADIUS := 1.3
const MOVE_SPEED := 11.0
const TURN_SPEED := 1.6
const FIRE_RANGE := 140.0
const FIRE_COOLDOWN := 0.35
const ENEMY_COUNT := 3
const ENEMY_SPEED := 5.5
const ENEMY_TURN := 1.1
const ENEMY_FIRE_RANGE := 58.0
const ENEMY_RADIUS := 1.4
const HULL_MAX := 3

var heading := 0.0
var speed_now := 0.0
var fire_cooldown := 0.0
var reticle_flash := 0.0
var score := 0
var hull := HULL_MAX
var tanks_left := 3
var game_over := false
var respawn_timer := 0.0
var rng := RandomNumberGenerator.new()

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

var enemies: Array[Dictionary] = []

@onready var tank: Node3D = $Tank
@onready var camera: Camera3D = $Tank/Camera3D
@onready var renderer: Node3D = $VectorWorld
@onready var status: Label = $HUD/Status
@onready var score_label: Label = $HUD/Score
@onready var hull_label: Label = $HUD/Hull
@onready var reticle: Label = $HUD/Reticle
@onready var gameover_label: Label = $HUD/GameOver
@onready var radar: Control = $HUD/Radar
@onready var vector_btn: Button = $HUD/Options/VectorBtn
@onready var model_btn: Button = $HUD/Options/ModelBtn
@onready var full_btn: Button = $HUD/Options/FullBtn


func _ready() -> void:
	rng.randomize()
	renderer.build_world(obstacles)
	renderer.set_enemies(enemies)
	vector_btn.disabled = true # the active mode: shown, not clickable
	model_btn.disabled = true # Adam's pin: 3D option disabled until populated
	full_btn.pressed.connect(toggle_fullscreen)
	reticle.pivot_offset = reticle.size * 0.5
	for i in ENEMY_COUNT:
		_spawn_enemy()
	_update_score_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			toggle_fullscreen()
		elif event.keycode == KEY_ENTER and game_over:
			_restart()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_fire()


func toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _process(delta: float) -> void:
	fire_cooldown = maxf(fire_cooldown - delta, 0.0)
	if reticle_flash > 0.0:
		reticle_flash = maxf(reticle_flash - delta * 5.0, 0.0)
		reticle.scale = Vector2.ONE * (1.0 + reticle_flash * 0.7)

	if game_over:
		renderer.update_enemies()
		radar.set_state(tank.position, heading, enemies, obstacles)
		return

	# --- player turning & driving ---
	var turn := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		turn += 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		turn -= 1.0
	heading += turn * TURN_SPEED * delta

	var drive := 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		drive += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		drive -= 1.0
	speed_now = drive * MOVE_SPEED
	var forward := Vector3(-sin(heading), 0, -cos(heading))
	var pos := tank.position + forward * speed_now * delta
	if Vector2(pos.x, pos.z).length() > WORLD_RADIUS:
		var clamped := Vector2(pos.x, pos.z).limit_length(WORLD_RADIUS)
		pos.x = clamped.x
		pos.z = clamped.y
	tank.position = _resolve_collisions(pos, TANK_RADIUS)
	tank.rotation.y = heading

	if Input.is_physical_key_pressed(KEY_SPACE):
		_fire()

	# --- enemies ---
	if respawn_timer > 0.0:
		respawn_timer -= delta
		if respawn_timer <= 0.0 and enemies.size() < ENEMY_COUNT:
			_spawn_enemy()
	_update_enemies(delta)
	renderer.update_enemies()
	radar.set_state(tank.position, heading, enemies, obstacles)

	var compass := int(round(rad_to_deg(-heading))) % 360
	if compass < 0:
		compass += 360
	status.text = "HDG %03d   SPD %+.0f   VECTOR MODE   [W/S drive · A/D turn · SPACE fire · F11 fullscreen]" % [compass, speed_now]


# ---------------------------------------------------------------- cannon

func _fire() -> void:
	if game_over or fire_cooldown > 0.0:
		return
	fire_cooldown = FIRE_COOLDOWN
	reticle_flash = 1.0
	var origin := camera.global_position
	var dir := -camera.global_transform.basis.z
	var best := FIRE_RANGE
	var hit_enemy: Dictionary = {}
	for ob in obstacles:
		var t := _ray_aabb(origin, dir, ob)
		if t > 0.0 and t < best:
			best = t
	for e in enemies:
		var box := {"kind": "box", "pos": e["pos"], "size": Vector3(2.6, 1.8, 2.6)}
		var t := _ray_aabb(origin, dir, box)
		if t > 0.0 and t < best:
			best = t
			hit_enemy = e
	var end := origin + dir * best
	# The tracer starts at the gun, low and right of the eye — a shot
	# drawn from the eye down its own axis projects to an invisible dot
	# (that was build 1's "Space doesn't fire" bug: it fired, unseen).
	var muzzle := origin + camera.global_transform.basis.x * 0.45 - camera.global_transform.basis.y * 0.5 + dir * 1.2
	renderer.add_tracer(muzzle, end, false)
	renderer.add_burst(end, 0.8)
	if not hit_enemy.is_empty():
		_kill_enemy(hit_enemy)


func _kill_enemy(e: Dictionary) -> void:
	renderer.add_burst(e["pos"] + Vector3(0, 1.0, 0), 2.2)
	enemies.erase(e)
	score += 100
	respawn_timer = 2.0
	_update_score_hud()


func _enemy_fire(e: Dictionary) -> void:
	var origin: Vector3 = e["pos"] + Vector3(0, 1.1, 0)
	var target := tank.position + Vector3(0, 1.0, 0)
	var dir := (target - origin).normalized()
	# A fair spread, not an oracle: rotate the aim a touch at random.
	var spread := rng.randf_range(-0.045, 0.045)
	dir = dir.rotated(Vector3.UP, spread)
	var blocked := FIRE_RANGE
	for ob in obstacles:
		var t := _ray_aabb(origin, dir, ob)
		if t > 0.0 and t < blocked:
			blocked = t
	var dist := origin.distance_to(target)
	var end := origin + dir * minf(blocked, FIRE_RANGE)
	# Does the shot pass through the player?
	var t_ca := (target - origin).dot(dir)
	var hit := false
	if t_ca > 0.0 and t_ca < blocked:
		var closest := origin + dir * t_ca
		if closest.distance_to(target) < 1.6:
			hit = true
			end = closest
	renderer.add_tracer(origin, end, true)
	renderer.add_burst(end, 0.6)
	if hit:
		_player_hit()


func _player_hit() -> void:
	hull -= 1
	_update_score_hud()
	if hull > 0:
		return
	tanks_left -= 1
	renderer.add_burst(tank.position + Vector3(0, 1.0, 0), 3.0)
	if tanks_left <= 0:
		game_over = true
		gameover_label.visible = true
		_update_score_hud()
		return
	# Fresh tank at the spawn plain; enemies keep the field but their
	# guns go quiet briefly so the respawn isn't an instant second death.
	hull = HULL_MAX
	tank.position = Vector3(0, 0, 8)
	heading = 0.0
	for e in enemies:
		e["cooldown"] = maxf(float(e["cooldown"]), 2.0)
	_update_score_hud()


func _restart() -> void:
	score = 0
	hull = HULL_MAX
	tanks_left = 3
	game_over = false
	gameover_label.visible = false
	tank.position = Vector3(0, 0, 8)
	heading = 0.0
	enemies.clear()
	for i in ENEMY_COUNT:
		_spawn_enemy()
	_update_score_hud()


func _update_score_hud() -> void:
	score_label.text = "SCORE %04d" % score
	hull_label.text = "HULL %d/%d   TANKS %d" % [maxi(hull, 0), HULL_MAX, maxi(tanks_left, 0)]


# ---------------------------------------------------------------- enemies

func _spawn_enemy() -> void:
	for attempt in 12:
		var a := rng.randf_range(0.0, TAU)
		var d := rng.randf_range(55.0, 85.0)
		var p := tank.position + Vector3(sin(a) * d, 0, cos(a) * d)
		if Vector2(p.x, p.z).length() > WORLD_RADIUS - 5.0:
			continue
		var clear := true
		for ob in obstacles:
			var s: Vector3 = ob["size"]
			if absf(p.x - ob["pos"].x) < s.x * 0.5 + 2.5 and absf(p.z - ob["pos"].z) < s.x * 0.5 + 2.5:
				clear = false
		if clear:
			enemies.append({"pos": p, "heading": rng.randf_range(0.0, TAU), "cooldown": rng.randf_range(1.0, 2.5)})
			return
	enemies.append({"pos": Vector3(40, 0, -40), "heading": 0.0, "cooldown": 2.0})


func _update_enemies(delta: float) -> void:
	for e in enemies:
		var pos: Vector3 = e["pos"]
		var to_player := tank.position - pos
		to_player.y = 0
		var dist := to_player.length()
		var dir := to_player / maxf(dist, 0.001)
		var desired := atan2(-dir.x, -dir.z)
		# Crude obstacle sense: something dead ahead, steer off it.
		var fwd := Vector3(-sin(float(e["heading"])), 0, -cos(float(e["heading"])))
		var probe := pos + fwd * 5.5
		for ob in obstacles:
			var s: Vector3 = ob["size"]
			var depth := s.z if ob["kind"] == "box" else s.x
			if absf(probe.x - ob["pos"].x) < s.x * 0.5 + 1.6 and absf(probe.z - ob["pos"].z) < depth * 0.5 + 1.6:
				desired += 0.9
				break
		var diff := angle_difference(float(e["heading"]), desired)
		e["heading"] = float(e["heading"]) + clampf(diff, -ENEMY_TURN * delta, ENEMY_TURN * delta)
		if dist > 4.0:
			fwd = Vector3(-sin(float(e["heading"])), 0, -cos(float(e["heading"])))
			var next := pos + fwd * ENEMY_SPEED * delta
			if Vector2(next.x, next.z).length() > WORLD_RADIUS:
				var cl := Vector2(next.x, next.z).limit_length(WORLD_RADIUS)
				next.x = cl.x
				next.z = cl.y
			e["pos"] = _resolve_collisions(next, ENEMY_RADIUS)
		e["cooldown"] = float(e["cooldown"]) - delta
		if float(e["cooldown"]) <= 0.0 and dist < ENEMY_FIRE_RANGE:
			_enemy_fire(e)
			e["cooldown"] = rng.randf_range(1.7, 3.0)


# ---------------------------------------------------------------- geometry

func _resolve_collisions(pos: Vector3, radius: float) -> Vector3:
	for ob in obstacles:
		var c: Vector3 = ob["pos"]
		var s: Vector3 = ob["size"]
		var hx := s.x * 0.5
		var hz := (s.z if ob["kind"] == "box" else s.x) * 0.5
		var closest := Vector3(clampf(pos.x, c.x - hx, c.x + hx), 0, clampf(pos.z, c.z - hz, c.z + hz))
		var diff := Vector2(pos.x - closest.x, pos.z - closest.z)
		var dist := diff.length()
		if dist < radius:
			if dist > 0.001:
				var pushed := Vector2(closest.x, closest.z) + diff.normalized() * radius
				pos.x = pushed.x
				pos.z = pushed.y
			else:
				pos.x = c.x + hx + radius
	return pos


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
