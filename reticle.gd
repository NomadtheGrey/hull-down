extends Control
## The classic open bracket-cross reticle, drawn as lines: two
## horizontal bars with end caps and stems, a gap in the middle —
## the 1980 gunsight, not a full crosshair.

var ink := Color(0.35, 1.0, 0.45)


func _draw() -> void:
	var c := size * 0.5
	var w := 2.0
	# Top bar, its end caps, and the stem rising from it.
	draw_line(c + Vector2(-36, -17), c + Vector2(36, -17), ink, w)
	draw_line(c + Vector2(-36, -17), c + Vector2(-36, -7), ink, w)
	draw_line(c + Vector2(36, -17), c + Vector2(36, -7), ink, w)
	draw_line(c + Vector2(0, -17), c + Vector2(0, -46), ink, w)
	# Bottom bar, mirrored.
	draw_line(c + Vector2(-36, 17), c + Vector2(36, 17), ink, w)
	draw_line(c + Vector2(-36, 17), c + Vector2(-36, 7), ink, w)
	draw_line(c + Vector2(36, 17), c + Vector2(36, 7), ink, w)
	draw_line(c + Vector2(0, 17), c + Vector2(0, 46), ink, w)
	# Centre tick.
	draw_line(c + Vector2(-4, 0), c + Vector2(4, 0), ink, w)
