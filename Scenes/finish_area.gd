extends Area3D


func _on_body_shape_entered(body_rid:RID, body:Node3D, body_shape_index:int, local_shape_index:int) -> void:
	print('WIN')
