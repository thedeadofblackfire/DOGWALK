extends ToppleEntity

func _ready() -> void:
	super._ready()
	self.add_to_group("TrippingHazard")
	connect("body_entered", _on_body_entered)

func _on_body_entered(body: Node3D):
	if body == Context.pinda: 
		SignalBus.emit_signal("pinda_tripping_hazard")
