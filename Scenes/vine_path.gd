extends Path3D

@export var bend_down = false as bool
@export var influence_dictionary = {'move_forward': 0.0, 'move_backward': 0.0, 'move_left': 0.0, 'move_right': 0.0} as Dictionary

@export_category("Vine Properties")
@export var linear_damp: float = 20
@export var collision_mask: int = 2

@onready var vine_controller := $VineController as CharacterBody3D
@onready var contoller_mesh := $VineController/MeshInstance3D as MeshInstance3D

var vine_in_contact: bool = false


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if event.is_action_pressed("click"):
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	handle_inputs(delta)
	add_next_point(delta)
	handle_collision()

var segment_points: Array = []
func handle_collision():
	if vine_controller.get_last_slide_collision() != null:
		var last_collision: CollisionObject3D = vine_controller.get_last_slide_collision().get_collider()
		if last_collision.collision_layer == 2:
			if not vine_in_contact: replace_segment() #Anchor ends on first contact
			vine_in_contact = true
			
			contoller_mesh.mesh.material.albedo_color = Color.GREEN
	else:
		if vine_in_contact: replace_segment() #Anchor starts when not contacting
		vine_in_contact = false
		
		contoller_mesh.mesh.material.albedo_color = Color.WHITE
	
	segment_points.append(vine_controller.global_position)

@onready var rope_scene: PackedScene = preload("res://Rope/path_3d_rope.tscn")
func replace_segment():
	var rope: Rope = rope_scene.instantiate()
	rope.curve.clear_points()
	for i in segment_points.size():
		rope.curve.add_point(segment_points[i])
	
	rope.linear_damp = linear_damp
	rope.collision_mask = collision_mask
	add_child(rope)
	
	curve.clear_points()
	segment_points.clear()
	

func handle_inputs(delta):
	handle_bend_down()
	for input in influence_dictionary.keys():
		iterate_directional_influence(input, delta)

func add_next_point(delta):
	if curve.point_count == 0: curve.add_point(vine_controller.global_position)
	
	var x_axis = calculate_x_axis(delta)
	var z_axis = calculate_z_axis(delta)
	var y_axis = calculate_y_axis(x_axis, z_axis, delta)
	
	var camera = get_viewport().get_camera_3d()
	var target_pos = Vector3(x_axis, y_axis, z_axis).rotated(Vector3.UP, camera.rotation.y)
	var new_point = curve.get_baked_points()[-1] + target_pos
	
	
	vine_controller.velocity = vine_controller.global_position.direction_to(new_point)
	vine_controller.move_and_slide()
	curve.add_point(vine_controller.global_position)

func handle_bend_down():
	bend_down = Input.is_action_pressed('bend_down')

func iterate_directional_influence(input, delta):
	var current_influence = influence_dictionary[input]
	var delta_multiplier = 1.0
	if Input.is_action_pressed(input):
		var new_influence_amount = (current_influence + (delta * delta_multiplier))
		influence_dictionary.set(input, [new_influence_amount, 1].min())
	else:
		var new_influence_amount = (current_influence - (delta * (delta_multiplier / 2)))
		influence_dictionary.set(input, [new_influence_amount, 0].max())

func calculate_x_axis(delta):
	return (influence_dictionary['move_right'] - influence_dictionary['move_left']) * delta

func calculate_z_axis(delta):
	return (influence_dictionary['move_backward'] - influence_dictionary['move_forward']) * delta

func calculate_y_axis(x_axis, z_axis, delta):
	var y_axis = delta - [abs(x_axis), abs(z_axis)].max()
	if bend_down:
		y_axis = -y_axis
	return y_axis
