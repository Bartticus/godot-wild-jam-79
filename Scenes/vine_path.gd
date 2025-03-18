extends Path3D

@onready var vine_controller := $VineController as CharacterBody3D

var influence_dictionary = {'move_forward': 0.0, 'move_backward': 0.0, 'move_left': 0.0, 'move_right': 0.0} as Dictionary

func _physics_process(delta: float) -> void:
	handle_inputs(delta)
	add_next_point(delta)

func handle_inputs(delta):
	for input in influence_dictionary.keys():
		iterate_directional_influence(input, delta)

func add_next_point(delta):
	var x_axis = calculate_x_axis(delta)
	var z_axis = calculate_z_axis(delta)
	var y_axis = calculate_y_axis(x_axis, z_axis, delta)
	var new_point = curve.get_baked_points()[-1] + Vector3(x_axis, y_axis, z_axis)
	curve.add_point(new_point)
	vine_controller.global_position = new_point

func iterate_directional_influence(input, delta):
	var current_influence = influence_dictionary[input]
	var delta_multiplier = 1
	if Input.is_action_pressed(input):
		var new_influence_amount = (current_influence + (delta * delta_multiplier))
		influence_dictionary.set(input, [new_influence_amount, 1].min())
	else:
		var new_influence_amount = (current_influence - (delta * delta_multiplier))
		influence_dictionary.set(input, [new_influence_amount, 0].max())

func calculate_x_axis(delta):
	return (influence_dictionary['move_right'] - influence_dictionary['move_left']) * delta

func calculate_z_axis(delta):
	return (influence_dictionary['move_backward'] - influence_dictionary['move_forward']) * delta

func calculate_y_axis(x_axis, z_axis, delta):
	return delta - [abs(x_axis), abs(z_axis)].max()
