extends Path3D

@export var bend_down: bool = false
@export var influence_y = 1.0
@export var influence_dictionary = {'move_forward': 0.0, 'move_backward': 0.0, 'move_left': 0.0, 'move_right': 0.0} as Dictionary
@export var turn_speed = 0.75
@export var add_point_interator = 0

@export_category("Vine Properties")
@export var max_length: float = 10
@export var linear_damp: float = 20
@export var collision_mask: int = 2
@export var segment_division: int = 10

@onready var vine_controller := $VineController as CharacterBody3D
@onready var contoller_mesh := $VineController/MeshInstance3D as MeshInstance3D
@onready var rope_scene: PackedScene = preload("res://Scenes/Rope/path_3d_rope.tscn")

var segment_points: Array = []
var last_contact_pos: Vector3
var vine_length: float
var vine_in_contact: bool = false
var in_freefall: bool = false:
	set(value):
		if in_freefall:
			if !value:
				end_freefall.emit() #Emits when freefall changes from true to false
			bend_down = true
		else:
			bend_down = false
		in_freefall = value

signal end_freefall

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Global.update_max_length(max_length)

func _physics_process(delta: float) -> void:
	handle_inputs(delta)
	add_next_point(delta)
	limit_vine_length()
	handle_collision()

func handle_inputs(delta):
	handle_bend_down(delta)
	for input in influence_dictionary.keys():
		var is_greatest_influence = influence_dictionary.find_key(get_greatest_influence()) == input
		iterate_directional_influence(input, delta, is_greatest_influence)

func get_greatest_influence():
	var sorted_influences = influence_dictionary.values()
	sorted_influences.sort()
	return sorted_influences[-1]

func add_next_point(delta):
	if curve.point_count == 0: curve.add_point(vine_controller.global_position)

	add_point_interator += 1
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
		if add_point_interator >= 10:
			add_point_interator = 0
			if not curve.get_baked_points().has(vine_controller.global_position):
				curve.add_point(vine_controller.global_position)

func handle_freefall(delta):
	var start_end_distance: float = vine_controller.global_position.distance_to(last_contact_pos)
	var magnitude: float = 10 * start_end_distance * start_end_distance * delta
	var gravity: float = 100 * delta
	
	#Applies force towards last contact, then applies gravity, then reduces velocity based on distance
	vine_controller.velocity += vine_controller.global_position.direction_to(last_contact_pos) * magnitude
	vine_controller.velocity.y -= gravity
	vine_controller.velocity = lerp(vine_controller.velocity, Vector3.ZERO, start_end_distance * delta)
	
	vine_controller.move_and_slide()

func handle_bend_down(delta):
	bend_down = Input.is_action_pressed('bend_down')
	# If we are pointing straight up, begin to tilt the vine slightly forward
	if (get_greatest_influence() == 0 && (bend_down || influence_y <= 0.0)):
		increase_directional_influence('move_forward', delta)

func iterate_directional_influence(input, delta, is_greatest_influence):
	if Input.is_action_pressed(input) || (is_greatest_influence && ((bend_down && influence_y > 0.0) || (influence_y <= 0.0 && !bend_down))):
		increase_directional_influence(input, delta)
	else:
		decrease_directional_influence(input, delta)

func increase_directional_influence(input, delta):
	var current_influence = influence_dictionary[input]
	var new_influence_amount = (current_influence + (delta * turn_speed))
	influence_dictionary.set(input, [new_influence_amount, 0.9].min())

func decrease_directional_influence(input, delta):
	var current_influence = influence_dictionary[input]
	var new_influence_amount = (current_influence - (delta * (turn_speed / 2)))
	influence_dictionary.set(input, [new_influence_amount, 0.1].max())

func calculate_x_axis(delta):
	return (influence_dictionary['move_right'] - influence_dictionary['move_left']) * delta

func calculate_z_axis(delta):
	return (influence_dictionary['move_backward'] - influence_dictionary['move_forward']) * delta

func calculate_y_axis(x_axis, z_axis, delta):
	var max_tilt = [abs(x_axis), abs(z_axis)].max()
	var y_axis = delta - max_tilt
	calculate_influence_y(delta)
	
	if (influence_y <= 0):
		y_axis = -y_axis
	return y_axis

func calculate_influence_y(delta):
	var existing_influence = 1.0 - get_greatest_influence()
	if (influence_y <= 0.0):
		existing_influence = -existing_influence
	if bend_down:
		influence_y = [[(influence_y - (delta * turn_speed)), existing_influence].min(), -1].max()
	else:
		influence_y = [[(influence_y + (delta * turn_speed)), existing_influence].max(), 1].min()

func limit_vine_length():
	vine_length = curve.get_baked_length()
	
	if vine_length > max_length and not in_freefall:
		in_freefall = true
		replace_segment()

func handle_collision():
	if vine_controller.get_last_slide_collision() != null:
		var last_collision: CollisionObject3D = vine_controller.get_last_slide_collision().get_collider()
		if last_collision.collision_layer == 2:
			if not vine_in_contact and not in_freefall:
				replace_segment() #Anchor ends on first contact
				Global.update_length(0)
			vine_in_contact = true
			in_freefall = false
			
			last_contact_pos = vine_controller.global_position
			contoller_mesh.mesh.material.albedo_color = Color.GREEN
	else:
		if vine_in_contact:
			last_contact_pos = vine_controller.global_position
			replace_segment() #Anchor starts when not contacting
		vine_in_contact = false
		
		Global.update_length(vine_length)
		contoller_mesh.mesh.material.albedo_color = Color.WHITE
	
	if not segment_points.has(vine_controller.global_position):
		segment_points.append(vine_controller.global_position)

func replace_segment():
	if segment_points.is_empty(): return
	
	var rope: Rope = rope_scene.instantiate()
	rope.curve.clear_points()
	
	for i in segment_points.size() - 1:
		if i * segment_division < segment_points.size():
			rope.curve.add_point(segment_points[i * segment_division])
	rope.curve.add_point(segment_points[-1])
	
	rope.linear_damp = linear_damp
	rope.collision_mask = collision_mask
	if in_freefall:
		rope.rigidbody_attached_to_end = vine_controller
		rope.fixed_end_point = false
		free_attachment(rope)
	
	add_child(rope)
	
	curve.clear_points() #Reset points before next curve starts
	segment_points.clear()

func free_attachment(existing_rope: Rope): #Replaces the rope from freefall with a copy
	await end_freefall #Called when setting in_freefall
	var rope: Rope = rope_scene.instantiate()
	rope.curve.clear_points()
	
	for i in existing_rope.curve.get_baked_points().size() - 1:
		rope.curve.add_point(existing_rope.curve.get_baked_points()[i])
	rope.curve.add_point(vine_controller.global_position) #Final point where controller is
	
	rope.linear_damp = existing_rope.linear_damp
	rope.collision_mask = existing_rope.collision_mask
	
	existing_rope.queue_free()
	add_child(rope)
	
	curve.clear_points()
	segment_points.clear()
