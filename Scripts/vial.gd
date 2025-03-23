extends Panel

@onready var vial_texture := $VialTexture as TextureRect

func _ready() -> void:
	Global.vial = self

func update_picture():
	var picture = load("res://Textures/Vial/vial_%02d.PNG" % (Global.vine_path.sunlight + Global.vine_path.nutrients + 1))
	vial_texture.texture = picture
