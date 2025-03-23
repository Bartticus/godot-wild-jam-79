extends TextureRect

func _ready() -> void:
	Global.vial = self

func _physics_process(_delta: float) -> void:
	var picture = load("res://Textures/Vial/vial_%02d.PNG" % (Global.vine_path.sunlight + Global.vine_path.nutrients + 1))
	texture = picture