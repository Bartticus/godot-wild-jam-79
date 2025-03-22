extends MeshInstance3D

@onready var vine_tip_light := $VineTipLight as OmniLight3D

var vine_path : Path3D

func activate_light():
	vine_tip_light.set_param(OmniLight3D.PARAM_ENERGY, 1.0)

func deactivate_light():
	vine_tip_light.set_param(OmniLight3D.PARAM_ENERGY, 0)
