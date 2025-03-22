extends TextureProgressBar

func _ready() -> void:
	Global.contact_meter = self

func _physics_process(_delta: float) -> void:
	if !Global.contact_timer.is_stopped():
		value = max_value - Global.contact_timer.time_left

func update_value(new_value):
	value = new_value
