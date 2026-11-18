extends Node3D
## Hull Down — scaffold scene.
## A static greybox plain with geometric obstacles and a slow camera pan,
## just enough to prove the project boots in 3D on laptop and tablet.
## Real tank movement, combat, radar and the vector look come later;
## game logic will stay renderer-agnostic so the later 3D-model mode
## can slide in beside the vector mode (Adam's pin, 2026-11-18).

var seconds := 0.0

@onready var camera: Camera3D = $Camera3D
@onready var sun: DirectionalLight3D = $Sun
@onready var status: Label = $HUD/Status


func _ready() -> void:
	camera.rotation_degrees.x = -14.0
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)


func _process(delta: float) -> void:
	seconds += delta
	# Gentle pan so the plain reads as a place, not a screenshot.
	camera.rotation_degrees.y = sin(seconds * 0.11) * 16.0
	status.text = "Scaffold running fine for %d seconds." % int(seconds)
