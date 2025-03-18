extends Path3D


func _on_spawn_timer_timeout() -> void:
	var new_point = curve.get_baked_points().get(curve.get_baked_points().size() - 1) + Vector3.UP
	curve.add_point(new_point)
	
	$Marker3D.global_position = new_point
