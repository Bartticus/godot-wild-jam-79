extends Node

@export var max_length: float
@export var flaccid_meter: TextureProgressBar

func update_max_length(new_max_length):
	max_length = new_max_length
	flaccid_meter.update_max_value(new_max_length)

func update_length(new_length):
	flaccid_meter.update_value(new_length)
