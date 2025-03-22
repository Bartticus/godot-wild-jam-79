extends Path3D

@export var bend_down: bool = false
@export var influence_y = 1.0
@export var influence_dictionary = {'move_forward': 0.0, 'move_backward': 0.0, 'move_left': 0.0, 'move_right': 0.0} as Dictionary
@export var turn_speed = 0.75

@export_category("Vine Properties")
@export var max_length: float = 5
@export var linear_damp: float = 20
@export var collision_mask: int = 2
@export var segment_division: int = 3

@onready var vine_controller := $VineController as CharacterBody3D
@onready var contoller_mesh := $VineController/MeshInstance3D as MeshInstance3D
@onready var rope_scene: PackedScene = preload("res://Scenes/Rope/path_3d_rope.tscn")
@onready var leaves_scene: PackedScene = preload("res://Scenes/vine_leaves.tscn")
@onready var contact_timer := $ContactTimer as Timer

var segment_points: Array = []
var add_point_interator = 0
var add_point_limit = 3
var contact_timer_ran_out = false
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
	Global.update_max_plant_power(max_length)
	Global.set_contact_timer(contact_timer)

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
		if add_point_interator >= add_point_limit:
			add_point_interator = 0
			if not curve.get_baked_points().has(vine_controller.global_position):
				curve.add_point(vine_controller.global_position)

func handle_freefall(delta):
	var start_end_distance: float = vine_controller.global_position.distance_to(last_contact_pos)
	var magnitude: float = 10 * start_end_distance * start_end_distance * delta / max_length
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
	set_vine_length()
	if Global.current_plant_power <= 0 and not in_freefall:
		in_freefall = true
		replace_segment()

func handle_collision():
	var last_collision = vine_controller.get_last_slide_collision()
	if last_collision && last_collision.get_collider().is_in_group('Climbable'):
		if vine_in_contact && can_create_vine() && !in_freefall:
			create_vine()
		if in_freefall:
			in_freefall = false
			Global.recharge_meter(0.2)
		vine_in_contact = true
		contoller_mesh.mesh.material.albedo_color = Color.GREEN
		
		if contact_timer.is_stopped() && !contact_timer_ran_out:
			contact_timer.start()
	else:
		if vine_in_contact:
			if can_create_vine():
				create_vine()
		if !contact_timer.is_stopped():
			contact_timer.stop()
		contact_timer_ran_out = false
		Global.reset_contact_meter()

		vine_in_contact = false
		contoller_mesh.mesh.material.albedo_color = Color.WHITE
	
	if not segment_points.has(vine_controller.global_position):
		segment_points.append(vine_controller.global_position)

func replace_segment():
	if segment_points.is_empty(): return
	
	var rope: Rope = rope_scene.instantiate()
	rope.curve.clear_points()
	
	for i in segment_points.size() - 1:
		if i * segment_division < segment_points.size(): #Divide segment points to include less
			rope.curve.add_point(segment_points[i * segment_division])
	
	
	
	if not rope.curve.get_baked_points().has(segment_points[-1]):
		rope.curve.add_point(segment_points[-1]) #Be sure to add the last point
	
	rope.number_of_segments = ceilf(curve.get_baked_length())
	if rope.number_of_segments < 2: #Dont create very short segments
		return
	
	spawn_leaves()
	
	rope.linear_damp = linear_damp
	rope.collision_mask = collision_mask
	rope.vine_controller = vine_controller
	if in_freefall:
		rope.rigidbody_attached_to_end = vine_controller
		rope.fixed_end_point = false
		free_attachment(rope)
	
	add_child(rope)
	
	curve.clear_points() #Reset points before next curve starts
	segment_points.clear()

func spawn_leaves():
	var last_collision: KinematicCollision3D
	if vine_controller.get_last_slide_collision():
		last_collision = vine_controller.get_last_slide_collision()
	
	if last_collision:
		var leaves: Node3D = leaves_scene.instantiate()
		add_child(leaves)
		
		leaves.global_position = segment_points[-1]
		leaves.scale = Vector3.ZERO
		leaves.look_at(vine_controller.global_position\
			 + vine_controller.get_last_slide_collision().get_normal(), Vector3.BACK)
		leaves.rotation.y += deg_to_rad(90)
		
		var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(leaves, "scale", Vector3.ONE * 0.5, 2)

func free_attachment(existing_rope: Rope): #Replaces the rope from freefall with a copy
	await end_freefall #Called when setting in_freefall
	
	var rope: Rope = rope_scene.instantiate()
	rope.curve.clear_points()
	#Not exactly duplicated from replace_segment func, couldn't make it work in a single func
	for i in existing_rope.curve.get_baked_points().size() - 1:
		rope.curve.add_point(existing_rope.curve.get_baked_points()[i])
	if not rope.curve.get_baked_points().has(vine_controller.global_position):
		rope.curve.add_point(vine_controller.global_position) #Final point where controller is
	
	rope.linear_damp = existing_rope.linear_damp
	rope.collision_mask = existing_rope.collision_mask
	rope.vine_controller = existing_rope.vine_controller
	
	existing_rope.queue_free()
	add_child(rope)
	
	curve.clear_points()
	segment_points.clear()


func can_create_vine():
	return contact_timer_ran_out

func create_vine():
	if !in_freefall:
		replace_segment() #Anchor ends on first contact
	last_contact_pos = vine_controller.global_position

func _on_contact_timer_timeout() -> void:
	contact_timer_ran_out = true
	Global.update_contact_meter(contact_timer.wait_time)

func set_vine_length():
	var old_length = vine_length
	vine_length = curve.get_baked_length()
	if vine_length >= old_length:
		if !vine_in_contact:
			Global.iterate_length(vine_length - old_length)
		elif !in_freefall:
			Global.recharge_meter(vine_length - old_length)
