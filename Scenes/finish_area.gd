extends Area3D


func _on_body_shape_entered(_body_rid:RID, _body:Node3D, _body_shape_index:int, _local_shape_index:int) -> void:
	Global.end_screen.activate()
