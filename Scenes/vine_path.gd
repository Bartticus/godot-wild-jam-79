extends Path3D

@export var bend_down = false as bool
@export var influence_dictionary = {'move_forward': 0.0, 'move_backward': 0.0, 'move_left': 0.0, 'move_right': 0.0} as Dictionary

@export_category("Vine Properties")
@export var max_length: float = 10
@export var linear_damp: float = 20
@export var collision_mask: int = 2

@onready var vine_controller := $VineController as CharacterBody3D
@onready var contoller_mesh := $VineController/MeshInstance3D as MeshInstance3D
@onready var rope_scene: PackedScene = preload("res://Rope/path_3d_rope.tscn")

var segment_points: Array = []
var last_contact_pos: Vector3
var vine_length: float
var vine_in_contact: bool = false
var in_freefall: bool = false:
	set(value):
		if in_freefall and not value:
			end_freefall.emit()
		in_freefall = value

signal end_freefall

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
	limit_vine_length()

func limit_vine_length():
	if in_freefall: return
	
	vine_length = vine_controller.global_position.distance_to(last_contact_pos)
	if vine_length > max_length:
		in_freefall = true
		replace_segment()

var segment_points: Array = []
func handle_collision():
	if vine_controller.get_last_slide_collision() != null:
		var last_collision: CollisionObject3D = vine_controller.get_last_slide_collision().get_collider()
		if last_collision.collision_layer == 2:
			if not vine_in_contact and not in_freefall: replace_segment() #Anchor ends on first contact
			vine_in_contact = true
			in_freefall = false
			contoller_mesh.mesh.material.albedo_color = Color.GREEN
	else:
		if vine_in_contact:
			last_contact_pos = vine_controller.global_position
			replace_segment() #Anchor starts when not contacting
		vine_in_contact = false
		
		contoller_mesh.mesh.material.albedo_color = Color.WHITE
	
	segment_points.append(vine_controller.global_position)

func replace_segment():
	if segment_points.is_empty(): return
	
	var rope: Rope = rope_scene.instantiate()
	rope.curve.clear_points()
	for i in segment_points.size():
		rope.curve.add_point(segment_points[i])
	
	rope.linear_damp = linear_damp
	rope.collision_mask = collision_mask
	if in_freefall:
		rope.rigidbody_attached_to_end = vine_controller
		rope.fixed_end_point = false
		free_attachment(rope)
	
	add_child(rope)
	
	curve.clear_points()
	segment_points.clear()

func free_attachment(_rope: Rope): #Replaces the rope from freefall with a copy
	await end_freefall
	var rope: Rope = rope_scene.instantiate()
	rope.curve.clear_points()
	
	for i in _rope.curve.get_baked_points().size() - 1:
		rope.curve.add_point(_rope.curve.get_baked_points()[i])
	
	rope.linear_damp = linear_damp
	rope.collision_mask = collision_mask
	
	_rope.queue_free()
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
	var new_point = vine_controller.global_position + target_pos
	
	vine_controller.velocity = vine_controller.global_position.direction_to(new_point)
	
	if in_freefall:
		handle_freefall(delta)
	else:
		vine_controller.move_and_slide()
		curve.add_point(vine_controller.global_position)

func handle_freefall(delta):
	var weight: float = 100
	vine_length = vine_controller.global_position.distance_to(last_contact_pos)
	if abs(vine_length - max_length) > 1 or vine_controller.global_position.y > last_contact_pos.y:
		vine_controller.velocity.y -= weight * delta #Pulls end of vine down until it's near max length
	
	#var speed_factor = max_length - clampf(vine_length, 0, max_length)
	#vine_controller.velocity = vine_controller.velocity.lerp(vine_controller.velocity.normalized() * speed_factor, weight * delta)
	vine_controller.move_and_slide()

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
