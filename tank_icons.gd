extends Control
## Remaining tanks, drawn as little tank silhouettes — the way the
## original shows lives — instead of a "TANKS 3" text counter.

var count := 3:
	set(value):
		count = value
		queue_redraw()

var ink := Color(0.35, 1.0, 0.45)


func _draw() -> void:
	for i in count:
		var o := Vector2(i * 36, 4)
		var w := 2.0
		# Hull.
		draw_line(o + Vector2(0, 10), o + Vector2(28, 10), ink, w)
		draw_line(o + Vector2(28, 10), o + Vector2(28, 18), ink, w)
		draw_line(o + Vector2(28, 18), o + Vector2(0, 18), ink, w)
		draw_line(o + Vector2(0, 18), o + Vector2(0, 10), ink, w)
		# Turret and barrel.
		draw_line(o + Vector2(9, 10), o + Vector2(9, 3), ink, w)
		draw_line(o + Vector2(9, 3), o + Vector2(20, 3), ink, w)
		draw_line(o + Vector2(20, 3), o + Vector2(20, 10), ink, w)
		draw_line(o + Vector2(20, 6), o + Vector2(30, 6), ink, w)
