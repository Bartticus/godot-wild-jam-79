extends Node3D

var align_camera: bool = false
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("click") or event.is_action_pressed("retract"):
		$IntroCamera/AnimationPlayer.play("start_zoom")
		create_tween().tween_property($Control/Label, "modulate:a", 0,1)
		await get_tree().create_timer(6).timeout
		align_camera = true
		await get_tree().create_timer(1).timeout
		Global.game_started = true
		Global.vine_path.camera.current = true

func _process(delta: float) -> void:
	if !align_camera: return
	
	var target = Global.vine_path.camera.global_transform
	$IntroCamera.global_transform = lerp($IntroCamera.global_transform, target, delta / 10)
