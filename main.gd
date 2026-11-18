extends Node3D
## Hull Down — game logic (renderer-agnostic).
## Owns all world state: the player's tank, bot enemies, cannon shells,
## waves, score and lives, and the procedural battlefield (obstacles
## are generated in chunks around the player, endlessly). It knows
## nothing about how the world is drawn: vector_renderer.gd draws this
## state as lines today; the future 3D-model mode reads the same state.
##
## Controls: W/S or Up/Down drive, A/D or Left/Right turn, Space or
## left mouse button fires, F11 toggles fullscreen.

const TANK_RADIUS := 1.3
const MOVE_SPEED := 11.0
const TURN_SPEED := 1.6
const FIRE_RANGE := 140.0
const FIRE_COOLDOWN := 0.45
const SHELL_SPEED := 72.0
const ENEMY_SHELL_SPEED := 54.0
const SHELL_GRAVITY := 1.4
const ENEMY_SPEED := 5.5
const ENEMY_TURN := 1.1
const ENEMY_FIRE_RANGE := 58.0
const ENEMY_RADIUS := 1.4
const ENEMY_MAX_ALIVE := 4
const SPAWN_MIN := 70.0
const SPAWN_MAX := 100.0
const HULL_MAX := 3
const CHUNK := 60.0
const CHUNK_RADIUS := 2 # 5x5 chunks of battlefield around the player
const MOUSE_SENS := 0.0032

var heading := 0.0
var speed_now := 0.0
var fire_cooldown := 0.0
var reticle_flash := 0.0
var score := 0
var hull := HULL_MAX
var tanks_left := 3
var game_over := false
var protection := 2.0 # spawn protection, seconds
var dead_timer := 0.0
var shake := 0.0
var hit_warn := 0.0
var flash_alpha := 0.0
var banner_time := 0.0
var wave := 0
var wave_spawned := 0
var wave_total := 0
var wave_state := "intro" # intro -> combat -> cleared -> intro ...
var wave_timer := 1.2
var high_score := 0
var rng := RandomNumberGenerator.new()
var touch_turn := 0 # -1..1, from the on-screen pads
var touch_drive := 0 # -1..1, from the on-screen pads
var mouse_captured := false

var obstacles: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var shells: Array[Dictionary] = [] # {pos, vel, player}
var _chunk_at := Vector2i(9999, 9999)

@onready var tank: Node3D = $Tank
@onready var camera: Camera3D = $Tank/Camera3D
@onready var renderer: Node3D = $VectorWorld
@onready var status: Label = $HUD/Status
@onready var score_label: Label = $HUD/Score
@onready var hull_label: Label = $HUD/Hull
@onready var wave_label: Label = $HUD/Wave
@onready var reticle: Control = $HUD/Reticle
@onready var hiscore_label: Label = $HUD/HiScore
@onready var warn_label: Label = $HUD/Warn
@onready var lives_icons: Control = $HUD/LivesIcons
@onready var banner: Label = $HUD/Banner
@onready var flash: ColorRect = $HUD/Flash
@onready var gameover_label: Label = $HUD/GameOver
@onready var radar: Control = $HUD/Radar
@onready var vector_btn: Button = $HUD/Options/VectorBtn
@onready var model_btn: Button = $HUD/Options/ModelBtn
@onready var full_btn: Button = $HUD/Options/FullBtn
@onready var solo_btn: Button = $HUD/PlayModes/SoloBtn
@onready var match_btn: Button = $HUD/PlayModes/MatchBtn
@onready var hint: Label = $HUD/Hint
@onready var touch_controls: Control = $HUD/TouchControls


func _ready() -> void:
	rng.randomize()
	renderer.build_world()
	renderer.set_enemies(enemies)
	renderer.set_shells(shells)
	vector_btn.disabled = true
	model_btn.disabled = true # Adam's pin: 3D option disabled until populated
	full_btn.pressed.connect(toggle_fullscreen)
	solo_btn.disabled = true # SOLO is the live mode
	match_btn.disabled = true # MATCH stays disabled until multiplayer is wired
	_bind_touch()
	_apply_touch_visibility(false)
	_load_high()
	reticle.pivot_offset = reticle.size * 0.5
	_rebuild_chunks(true)
	_update_score_hud()


## Touch pads feed the same turn/drive values the keyboard does, so
## touch and keyboard/mouse buildouts stay simultaneous from here on
## (Adam's pin — never assume the player is on a PC).
func _bind_touch() -> void:
	var fwd: Button = $HUD/TouchControls/FwdBtn
	var back: Button = $HUD/TouchControls/BackBtn
	var left: Button = $HUD/TouchControls/TurnLeftBtn
	var right: Button = $HUD/TouchControls/TurnRightBtn
	var fire: Button = $HUD/TouchControls/FireBtn
	fwd.button_down.connect(func() -> void: touch_drive = 1)
	fwd.button_up.connect(func() -> void: if touch_drive == 1: touch_drive = 0)
	back.button_down.connect(func() -> void: touch_drive = -1)
	back.button_up.connect(func() -> void: if touch_drive == -1: touch_drive = 0)
	left.button_down.connect(func() -> void: touch_turn = 1)
	left.button_up.connect(func() -> void: if touch_turn == 1: touch_turn = 0)
	right.button_down.connect(func() -> void: touch_turn = -1)
	right.button_up.connect(func() -> void: if touch_turn == -1: touch_turn = 0)
	fire.button_down.connect(_fire)


func _apply_touch_visibility(force: bool) -> void:
	touch_controls.visible = force or DisplayServer.is_touchscreen_available()
	hint.visible = not touch_controls.visible


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true
	hint.visible = false


func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_captured = false
	hint.visible = not touch_controls.visible


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_captured:
		heading -= event.relative.x * MOUSE_SENS
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			toggle_fullscreen()
		elif event.keycode == KEY_ESCAPE and mouse_captured:
			_release_mouse()
		elif event.keycode == KEY_ENTER and game_over:
			_restart()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# PC mouse play: the first click on the view captures the mouse
		# (move = steer); clicks while captured fire the cannon.
		if mouse_captured:
			_fire()
		else:
			_capture_mouse()


func toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _process(delta: float) -> void:
	fire_cooldown = maxf(fire_cooldown - delta, 0.0)
	protection = maxf(protection - delta, 0.0)
	hit_warn = maxf(hit_warn - delta, 0.0)
	if reticle_flash > 0.0:
		reticle_flash = maxf(reticle_flash - delta * 5.0, 0.0)
		reticle.scale = Vector2.ONE * (1.0 + reticle_flash * 0.7)
	if flash_alpha > 0.0:
		flash_alpha = maxf(flash_alpha - delta * 1.8, 0.0)
		flash.color = Color(1.0, 0.15, 0.1, flash_alpha * 0.45)
	if banner_time > 0.0:
		banner_time -= delta
		if banner_time <= 0.0:
			banner.visible = false
	status.modulate = Color(1, 0.35, 0.3) if hit_warn > 0.0 else Color(1, 1, 1)

	_update_waves(delta)
	_update_shells(delta)
	renderer.follow(tank.position)
	radar.set_state(tank.position, heading, enemies, obstacles)
	_update_warn()

	if game_over:
		renderer.update_enemies()
		return

	if dead_timer > 0.0:
		# Wrecked: no driving while the explosion clears.
		dead_timer -= delta
		_apply_shake(delta)
		if dead_timer <= 0.0:
			_respawn()
		renderer.update_enemies()
		return

	# The browser/OS can take pointer capture back (Esc) without asking.
	if mouse_captured and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
		mouse_captured = false
		hint.visible = not touch_controls.visible

	# --- player turning & driving (keyboard + touch pads together) ---
	var turn := float(touch_turn)
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		turn += 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		turn -= 1.0
	heading += clampf(turn, -1.0, 1.0) * TURN_SPEED * delta

	var drive := float(touch_drive)
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		drive += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		drive -= 1.0
	drive = clampf(drive, -1.0, 1.0)
	speed_now = drive * MOVE_SPEED
	var forward := Vector3(-sin(heading), 0, -cos(heading))
	tank.position = _resolve_collisions(tank.position + forward * speed_now * delta, TANK_RADIUS)
	tank.rotation.y = heading
	_apply_shake(delta)

	if Input.is_physical_key_pressed(KEY_SPACE):
		_fire()

	_update_enemies(delta)
	renderer.update_enemies()
	_rebuild_chunks(false)

	var compass := int(round(rad_to_deg(-heading))) % 360
	if compass < 0:
		compass += 360
	var warn := "   — HULL HIT —" if hit_warn > 0.0 else ""
	status.text = "HDG %03d   SPD %+.0f   VECTOR MODE%s" % [compass, speed_now, warn]


func _apply_shake(delta: float) -> void:
	if shake > 0.0:
		shake = maxf(shake - delta * 1.6, 0.0)
		var s := shake * 0.14
		camera.position = Vector3(rng.randf_range(-s, s), 1.6 + rng.randf_range(-s, s), rng.randf_range(-s, s))
	else:
		camera.position = Vector3(0, 1.6, 0)


func _show_banner(text: String, seconds: float) -> void:
	banner.text = text
	banner.visible = true
	banner_time = seconds


# ---------------------------------------------------------------- waves

func _update_waves(delta: float) -> void:
	if game_over:
		return
	match wave_state:
		"intro":
			wave_timer -= delta
			if wave_timer <= 0.0:
				wave += 1
				wave_total = 2 + wave
				wave_spawned = 0
				wave_state = "combat"
				_show_banner("WAVE %d" % wave, 1.8)
				_update_score_hud()
		"combat":
			if wave_spawned < wave_total and enemies.size() < ENEMY_MAX_ALIVE:
				_spawn_enemy()
				wave_spawned += 1
				_update_score_hud()
			elif wave_spawned >= wave_total and enemies.is_empty():
				score += 250
				_save_high()
				wave_state = "cleared"
				wave_timer = 2.6
				_show_banner("WAVE %d CLEARED  +250" % wave, 2.4)
				_update_score_hud()
		"cleared":
			wave_timer -= delta
			if wave_timer <= 0.0:
				wave_state = "intro"
				wave_timer = 0.8


func _restart() -> void:
	score = 0
	hull = HULL_MAX
	tanks_left = 3
	wave = 0
	wave_state = "intro"
	wave_timer = 1.0
	game_over = false
	gameover_label.visible = false
	tank.position = Vector3(0, 0, 8)
	heading = 0.0
	protection = 2.0
	enemies.clear()
	shells.clear()
	_rebuild_chunks(true)
	_update_score_hud()


func _update_score_hud() -> void:
	if score > high_score:
		high_score = score
	score_label.text = "SCORE %06d" % score
	hiscore_label.text = "HI %06d" % high_score
	hull_label.text = "HULL %d/%d" % [maxi(hull, 0), HULL_MAX]
	lives_icons.count = maxi(tanks_left, 0)
	var hostiles := wave_total - wave_spawned + enemies.size()
	wave_label.text = "WAVE %d   HOSTILES %d" % [maxi(wave, 1), maxi(hostiles, 0)]


func _load_high() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://hulldown.cfg") == OK:
		high_score = int(cfg.get_value("scores", "high", 0))


func _save_high() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "high", high_score)
	cfg.save("user://hulldown.cfg")


## The original's red warning panel: the nearest hostile, how close,
## and where it sits relative to your nose.
func _update_warn() -> void:
	var nearest: Dictionary = {}
	var best := 1e9
	for e in enemies:
		var d: float = (e["pos"] as Vector3).distance_to(tank.position)
		if d < best:
			best = d
			nearest = e
	if nearest.is_empty() or best > 75.0:
		warn_label.visible = false
		return
	var dir: Vector3 = nearest["pos"] - tank.position
	var bearing := atan2(-dir.x, -dir.z)
	var diff := angle_difference(heading, bearing)
	var where := ""
	if diff > 0.55 and diff < 2.6:
		where = "ENEMY TO LEFT"
	elif diff < -0.55 and diff > -2.6:
		where = "ENEMY TO RIGHT"
	elif absf(diff) >= 2.6:
		where = "ENEMY TO REAR"
	var lines: Array[String] = []
	if best <= ENEMY_FIRE_RANGE:
		lines.append("ENEMY IN RANGE")
	if where != "":
		lines.append(where)
	if lines.is_empty():
		warn_label.visible = false
		return
	warn_label.text = "\n".join(lines)
	warn_label.visible = true


# ---------------------------------------------------------------- battlefield

func _chunk_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / CHUNK), floori(pos.z / CHUNK))


func _rebuild_chunks(force: bool) -> void:
	var here := _chunk_of(tank.position)
	if not force and here == _chunk_at:
		return
	_chunk_at = here
	obstacles.clear()
	for cx in range(here.x - CHUNK_RADIUS, here.x + CHUNK_RADIUS + 1):
		for cz in range(here.y - CHUNK_RADIUS, here.y + CHUNK_RADIUS + 1):
			_gen_chunk(cx, cz)
	renderer.rebuild_obstacles(obstacles)


func _gen_chunk(cx: int, cz: int) -> void:
	# Deterministic per chunk: leave and return, the field is the same.
	var s: int = cx * 374761393 + cz * 668265263
	s = (s ^ (s >> 13)) * 1274126177
	var r := RandomNumberGenerator.new()
	r.seed = s ^ (s >> 16)
	if r.randf() < 0.22:
		return
	var count := r.randi_range(1, 3)
	for i in count:
		var p := Vector3(cx * CHUNK + r.randf_range(7.0, CHUNK - 7.0), 0, cz * CHUNK + r.randf_range(7.0, CHUNK - 7.0))
		# Never drop a rock on the spawn plain or on the player's nose.
		if p.distance_to(Vector3(0, 0, 8)) < 16.0 or p.distance_to(tank.position) < 12.0:
			continue
		if r.randf() < 0.58:
			var w := r.randf_range(2.0, 3.5)
			obstacles.append({"kind": "box", "pos": p, "size": Vector3(w, r.randf_range(2.0, 4.0), w)})
		else:
			obstacles.append({"kind": "pyramid", "pos": p, "size": Vector3(r.randf_range(3.5, 6.0), r.randf_range(3.0, 4.5), 0)})


# ---------------------------------------------------------------- cannon & shells

func _fire() -> void:
	if game_over or dead_timer > 0.0 or fire_cooldown > 0.0:
		return
	fire_cooldown = FIRE_COOLDOWN
	reticle_flash = 1.0
	var origin := camera.global_position
	var dir := -camera.global_transform.basis.z
	# Aim convergence: the shell flies from the low gun to the point the
	# reticle actually covers, so what you point at is what you hit.
	var aim := origin + dir * _aim_distance(origin, dir)
	var muzzle := origin + camera.global_transform.basis.x * 0.45 - camera.global_transform.basis.y * 0.5 + dir * 1.2
	var vel := (aim - muzzle).normalized() * SHELL_SPEED
	shells.append({"pos": muzzle, "vel": vel, "player": true})


func _aim_distance(origin: Vector3, dir: Vector3) -> float:
	var best := 80.0
	for ob in obstacles:
		var t := _ray_aabb(origin, dir, ob)
		if t > 0.0 and t < best:
			best = t
	for e in enemies:
		var box := {"kind": "box", "pos": e["pos"], "size": Vector3(2.6, 1.8, 2.6)}
		var t := _ray_aabb(origin, dir, box)
		if t > 0.0 and t < best:
			best = t
	return best


func _update_shells(delta: float) -> void:
	for i in range(shells.size() - 1, -1, -1):
		var sh := shells[i]
		var vel: Vector3 = sh["vel"]
		vel.y -= SHELL_GRAVITY * delta
		sh["vel"] = vel
		var pos: Vector3 = sh["pos"] + vel * delta
		sh["pos"] = pos
		var dead := false
		if pos.y <= 0.0:
			renderer.add_burst(Vector3(pos.x, 0.2, pos.z), 0.7)
			dead = true
		else:
			for ob in obstacles:
				if _point_hits_obstacle(pos, ob):
					renderer.add_burst(pos, 0.9)
					dead = true
					break
		if not dead and bool(sh["player"]):
			for e in enemies.duplicate():
				var ep: Vector3 = e["pos"]
				if absf(pos.x - ep.x) < 1.5 and absf(pos.z - ep.z) < 1.5 and pos.y < 2.0:
					_kill_enemy(e)
					dead = true
					break
		if not dead and not bool(sh["player"]) and protection <= 0.0 and dead_timer <= 0.0 and not game_over:
			var centre := tank.position + Vector3(0, 1.0, 0)
			if pos.distance_to(centre) < 1.7:
				_player_hit()
				dead = true
		if not dead and pos.distance_to(tank.position) > 220.0:
			dead = true
		if dead:
			shells.remove_at(i)


func _point_hits_obstacle(p: Vector3, ob: Dictionary) -> bool:
	var c: Vector3 = ob["pos"]
	var s: Vector3 = ob["size"]
	if ob["kind"] == "box":
		return absf(p.x - c.x) < s.x * 0.5 and absf(p.z - c.z) < s.z * 0.5 and p.y >= 0.0 and p.y < s.y
	# Square pyramid: the higher the point, the smaller the cross-section.
	if p.y < 0.0 or p.y >= s.y:
		return false
	var half_at_y := s.x * 0.5 * (1.0 - p.y / s.y)
	return absf(p.x - c.x) < half_at_y and absf(p.z - c.z) < half_at_y


func _kill_enemy(e: Dictionary) -> void:
	renderer.add_burst(e["pos"] + Vector3(0, 1.0, 0), 2.2)
	enemies.erase(e)
	score += 100
	_update_score_hud()


func _enemy_fire(e: Dictionary) -> void:
	var origin: Vector3 = e["pos"] + Vector3(0, 1.2, 0) + Vector3(-sin(float(e["heading"])), 0, -cos(float(e["heading"]))) * 2.0
	var target := tank.position + Vector3(0, 1.0, 0)
	var dir := (target - origin).normalized()
	var spread := rng.randf_range(-0.045, 0.045)
	dir = dir.rotated(Vector3.UP, spread)
	shells.append({"pos": origin, "vel": dir * ENEMY_SHELL_SPEED, "player": false})


func _player_hit() -> void:
	hull -= 1
	hit_warn = 1.2
	flash_alpha = 1.0
	shake = 0.5
	_update_score_hud()
	if hull > 0:
		return
	# Destroyed — this part must be unmissable.
	tanks_left -= 1
	renderer.add_burst(tank.position + Vector3(0, 1.0, 0), 3.2)
	renderer.add_burst(tank.position + Vector3(0.8, 0.6, 0.4), 2.0)
	flash_alpha = 1.0
	shake = 1.0
	if tanks_left <= 0:
		game_over = true
		_save_high()
		gameover_label.text = "GAME OVER\nSCORE %06d\n\nPress ENTER to restart" % score
		gameover_label.visible = true
		_update_score_hud()
		return
	dead_timer = 1.5
	_show_banner("TANK DESTROYED", 1.5)
	_update_score_hud()


func _respawn() -> void:
	hull = HULL_MAX
	protection = 3.0
	# Nobody camps the wreck: hostiles near the respawn get pushed back
	# out to the spawn ring, and their guns stay quiet during protection.
	for e in enemies:
		var ep: Vector3 = e["pos"]
		if ep.distance_to(tank.position) < 40.0:
			e["pos"] = _spawn_point()
		e["cooldown"] = maxf(float(e["cooldown"]), 2.0)
	_show_banner("TANK %d READY" % (4 - tanks_left), 1.6)
	_update_score_hud()


# ---------------------------------------------------------------- enemies

func _spawn_point() -> Vector3:
	for attempt in 16:
		var a := rng.randf_range(0.0, TAU)
		var d := rng.randf_range(SPAWN_MIN, SPAWN_MAX)
		var p := tank.position + Vector3(sin(a) * d, 0, cos(a) * d)
		var clear := true
		for ob in obstacles:
			var s: Vector3 = ob["size"]
			if absf(p.x - ob["pos"].x) < s.x * 0.5 + 2.5 and absf(p.z - ob["pos"].z) < s.x * 0.5 + 2.5:
				clear = false
		if clear:
			return p
	# Fallback: still far — on the ring, due "north" of the player.
	return tank.position + Vector3(0, 0, -SPAWN_MAX)


func _spawn_enemy() -> void:
	var p := _spawn_point()
	enemies.append({"pos": p, "heading": rng.randf_range(0.0, TAU), "cooldown": rng.randf_range(1.2, 2.5)})
	renderer.add_burst(p + Vector3(0, 1.0, 0), 1.2)


func _update_enemies(delta: float) -> void:
	if dead_timer > 0.0 or game_over:
		return
	for e in enemies:
		var pos: Vector3 = e["pos"]
		var to_player := tank.position - pos
		to_player.y = 0
		var dist := to_player.length()
		var dir := to_player / maxf(dist, 0.001)
		var desired := atan2(-dir.x, -dir.z)
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
			e["pos"] = _resolve_collisions(pos + fwd * ENEMY_SPEED * delta, ENEMY_RADIUS)
		e["cooldown"] = float(e["cooldown"]) - delta
		if float(e["cooldown"]) <= 0.0 and dist < ENEMY_FIRE_RANGE and protection <= 0.0:
			_enemy_fire(e)
			e["cooldown"] = rng.randf_range(1.7, 3.0)


# ---------------------------------------------------------------- geometry

func _resolve_collisions(pos: Vector3, radius: float) -> Vector3:
	for ob in obstacles:
		var c: Vector3 = ob["pos"]
		var s: Vector3 = ob["size"]
		var hx := s.x * 0.5
		var hz := (s.z if ob["kind"] == "box" else s.x) * 0.5
		if ob["kind"] == "pyramid":
			# A tank meets the slope, not the base's full square: at hull
			# height the pyramid has already narrowed.
			var shrink := clampf(1.0 - 1.1 / s.y, 0.25, 1.0)
			hx *= shrink
			hz *= shrink
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


# Slab-method ray vs a bounding box (used for aim convergence only —
# shots themselves are travelling shells now, not rays).
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
