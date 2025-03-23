extends Node

var max_plant_power: float
var current_plant_power: float = max_plant_power
var current_vine_length: float = 0.0
var recharge_amount: float = 0.0
var recharge_rate: float = 2.0
var flaccid_meter: FlaccidMeter
var contact_timer: Timer
var contact_meter: TextureProgressBar
var vine_path: Vine
var vial: TextureRect
var game_started: bool = false

func _physics_process(_delta: float) -> void:
	if power_is_charged() && flaccid_meter:
		reset_plant_power()

func update_max_plant_power(new_max_plant_power):
	max_plant_power = new_max_plant_power
	flaccid_meter.update_max_value(new_max_plant_power)

func iterate_length(new_length):
	current_vine_length += new_length
	calculate_current_plant_power()

func iterate_contact_length(new_length):
	recharge_amount += new_length
	calculate_current_plant_power()

func recharge_meter(new_recharge_value):
	recharge_amount += (new_recharge_value * recharge_rate)
	calculate_current_plant_power()
	
func calculate_current_plant_power():
	var new_plant_power = max_plant_power - current_vine_length + recharge_amount
	# Sort and pick the middle value to max sure we don't go below/above the min/max
	var possible_values = [0, new_plant_power, max_plant_power]
	possible_values.sort()
	current_plant_power = possible_values[1]
	
	var meter_ratio: float = current_plant_power / max_plant_power
	flaccid_meter.update_value(meter_ratio)

func reset_plant_power():
	current_plant_power = max_plant_power
	current_vine_length = 0.0
	recharge_amount = 0.0
	flaccid_meter.update_value(current_plant_power)

func power_is_charged():
	return current_plant_power >= max_plant_power


func set_contact_timer(new_timer: Timer):
	contact_timer = new_timer
	contact_meter.max_value = new_timer.wait_time

func update_contact_meter(new_value):
	contact_meter.update_value(new_value)

func reset_contact_meter():
	if contact_meter.value > 0.0:
		contact_meter.update_value(0.0)
