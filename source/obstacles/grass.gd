extends ToppleEntity

func _ready() -> void:
	super._ready()
	self.add_to_group("CollisionGrass")
