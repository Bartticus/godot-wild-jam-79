extends Node3D


func _ready() -> void:
	randomize()
	$AudioStreamPlayer3D.pitch_scale = randf_range(0.8, 1.2)
	$AudioStreamPlayer3D.play()
