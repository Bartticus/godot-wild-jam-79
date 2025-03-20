extends Path3D

@export var bend_down = false as bool
@export var influence_y = 1.0
@export var influence_dictionary = {'move_forward': 0.0, 'move_backward': 0.0, 'move_left': 0.0, 'move_right': 0.0} as Dictionary
@export var turn_speed = 0.75

@export_category("Vine Properties")
@export var max_length: float = 10
@export var linear_damp: float = 20
@export var collision_mask: int = 2
@export var segment_division: int = 10

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
		
	if not curve.get_baked_points().has(vine_controller.global_position):
		curve.add_point(vine_controller.global_position)

func handle_freefall(delta):
	var weight: float = 100
	vine_length = vine_controller.global_position.distance_to(last_contact_pos)
	if abs(vine_length - max_length) > 1 or vine_controller.global_position.y > last_contact_pos.y:
		vine_controller.velocity.y -= weight * delta #Pulls end of vine down until it's near max length
	
	#var speed_factor = max_length - clampf(vine_length, 0, max_length)
	#vine_controller.velocity = vine_controller.velocity.lerp(vine_controller.velocity.normalized() * speed_factor, weight * delta)
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
