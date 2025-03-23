extends MeshInstance3D

@onready var vine_tip_light := $VineTipLight as OmniLight3D

var GREEN_LIGHT = Color(0, 0.59, 0)
var RED_LIGHT = Color(0.59, 0, 0)
var vine_path : Path3D

func activate_light(good_surface):
	vine_tip_light.light_color = GREEN_LIGHT if good_surface else RED_LIGHT
	vine_tip_light.set_param(OmniLight3D.PARAM_ENERGY, 1.0)

func deactivate_light():
	vine_tip_light.set_param(OmniLight3D.PARAM_ENERGY, 0)
