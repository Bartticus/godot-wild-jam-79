extends Area3D

@export var max_length_boost: int = 5

func _on_body_entered(body: Node3D) -> void:
	if body.get_parent() is Vine:
		var vine: Vine = body.get_parent()
		vine.max_length += max_length_boost
		Global.update_max_plant_power(vine.max_length)
		
		$Shinies.process_material.attractor_interaction_enabled = true
		$Shinies.emitting = false
		
		var tween: Tween = create_tween().set_trans(Tween.TRANS_BOUNCE)
		tween.tween_property($MeshInstance3D, "mesh:material:albedo_color:a", 1 ,0.25)
		tween.tween_property($MeshInstance3D, "mesh:material:albedo_color:a", 0 ,1)
		
		$CollisionShape3D.set_deferred("disabled", true)
