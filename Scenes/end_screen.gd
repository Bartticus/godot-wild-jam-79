extends Control

@onready var sunlight_label := %SunlightLabel as Label
@onready var nutrient_label := %NutrientLabel as Label
@onready var vial_texture := %VialTexture as TextureRect

func _ready() -> void:
	Global.end_screen = self

func activate():
	get_tree().paused = true
	visible = true
	Global.vial.visible = false
	var sunlight = Global.vine_path.sunlight
	var nutrients = Global.vine_path.nutrients

	sunlight_label.text = "You absorbed %d/3 Sunlight" % sunlight
	nutrient_label.text = "You collected %d/10 Nutrients" % nutrients

	var picture = load("res://Textures/Vial/vial_%02d.PNG" % (sunlight + nutrients + 1))
	vial_texture.texture = picture
