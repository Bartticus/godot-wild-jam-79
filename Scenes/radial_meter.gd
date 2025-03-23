class_name FlaccidMeter
extends AnimatedSprite3D


func _ready() -> void:
	Global.flaccid_meter = self

func update_max_value(_new_max_value):
	pass

var anim_frame_count = 42 #Match this to sprite frame count
func update_value(new_ratio):
	var next_frame: int = roundi(new_ratio * anim_frame_count)
	if next_frame == anim_frame_count - 1 or next_frame == 0:
		if not (frame == anim_frame_count - 1 or frame == 0): #Checks previous frame for changes
			$MeterTimer.start() #Only when reaching desired frame once
	
	frame = next_frame

func _process(_delta: float) -> void:
	if frame == anim_frame_count - 1 or frame == 0:
		if $MeterTimer.is_stopped():
			modulate.a = lerpf(modulate.a, 0, .1)
	else:
		$MeterTimer.stop()
		modulate.a = lerpf(modulate.a, 1, .1)
