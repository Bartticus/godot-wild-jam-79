extends TextureProgressBar

#func _ready() -> void:
	#Global.flaccid_meter = self

func update_max_value(new_max_value):
	max_value = new_max_value

func update_value(new_value):
	value = new_value
