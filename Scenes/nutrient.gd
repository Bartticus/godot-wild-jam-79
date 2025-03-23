extends Area3D


func _on_body_entered(body: Node3D) -> void:
	if body.get_parent() is Vine:
		Global.vine_path.increase_nutrients()
		Global.vial.update_picture()
		
		$Circles.process_material.attractor_interaction_enabled = true
		$Lines.emitting = false
		$Circles.emitting = false
		
		var tween: Tween = create_tween().set_trans(Tween.TRANS_BOUNCE)
		tween.tween_property($OmniLight3D, "light_energy", 0 ,2)
		
		$CollisionShape3D.set_deferred("disabled", true)
		
		$AudioStreamPlayer3D.play()
