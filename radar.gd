extends Control
## Hull Down — radar scope.
## Heading-up circular scope: the player sits at the centre, the top
## of the scope is where the tank faces. Enemy tanks are red blips,
## obstacles faint green, and a sweep arm rotates. Pure HUD: main.gd
## hands it state each frame via set_state; it decides nothing.

const RANGE := 60.0

var _player := Vector3.ZERO
var _heading := 0.0
var _enemies: Array = []
var _obstacles: Array = []
var _sweep := 0.0


func set_state(player: Vector3, heading: float, enemies: Array, obstacles: Array) -> void:
	_player = player
	_heading = heading
	_enemies = enemies
	_obstacles = obstacles


func _process(delta: float) -> void:
	_sweep = fmod(_sweep + delta * 1.4, TAU)
	queue_redraw()


func _blip(target: Vector3, center: Vector2, scale: float) -> Vector2:
	# Rotate the world offset into the tank's frame: forward becomes up.
	var rel := target - _player
	var fwd := Vector2(-sin(_heading), -cos(_heading)) # in XZ
	var right := Vector2(cos(_heading), -sin(_heading))
	var rel2 := Vector2(rel.x, rel.z)
	var sx := rel2.dot(right)
	var sy := rel2.dot(fwd)
	var p := center + Vector2(sx, -sy) * scale
	var max_r := size.x * 0.5 - 5.0
	if (p - center).length() > max_r:
		p = center + (p - center).normalized() * max_r
	return p


func _draw() -> void:
	var center := size * 0.5
	var r := size.x * 0.5 - 2.0
	var scale := r / RANGE
	var green := Color(0.3, 1.0, 0.4)
	draw_circle(center, r, Color(0.0, 0.06, 0.01, 0.6))
	draw_arc(center, r, 0, TAU, 64, green, 1.5)
	draw_arc(center, r * 0.5, 0, TAU, 48, Color(0.3, 1.0, 0.4, 0.35), 1.0)
	# Sweep arm.
	draw_line(center, center + Vector2(sin(_sweep), -cos(_sweep)) * r, Color(0.3, 1.0, 0.4, 0.5), 1.5)
	# Obstacles, faint.
	for ob in _obstacles:
		draw_circle(_blip(ob["pos"], center, scale), 2.0, Color(0.3, 1.0, 0.4, 0.4))
	# Enemies, red — the whole point of the scope.
	for e in _enemies:
		draw_circle(_blip(e["pos"], center, scale), 3.5, Color(1.0, 0.25, 0.2))
	# The player, centre.
	draw_circle(center, 3.0, Color(0.9, 1.0, 0.9))
