extends Label3D

func _ready() -> void:
	modulate.a = 0
	outline_modulate.a = 0

func _process(delta: float) -> void:
	if Global.vine_path.vine_controller.global_position.distance_to(global_position) > 5:
		modulate.a = lerpf(modulate.a, 0, delta)
		outline_modulate.a = lerpf(outline_modulate.a, 0, delta)
	else:
		modulate.a = lerpf(modulate.a, 1, delta)
		outline_modulate.a = lerpf(outline_modulate.a, 1, delta)
