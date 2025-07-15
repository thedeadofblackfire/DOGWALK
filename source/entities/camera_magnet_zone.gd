extends Area3D
class_name CameraMagnetZone

@export_category("Variables")
@export var magnet_position_override := 0.8
@export_range(0.0, 1.5) var magnet_zoom_override := 0.5

@export_group("Members Variables")
@export var interest_point : Marker3D
@export var collision_shape : CollisionShape3D

@onready var radius : float = collision_shape.shape.radius

signal zone_disabled()
signal zone_enabled()

@export var disabled : bool:
	get():
		return collision_shape.disabled
	set(value):
		if value != collision_shape.disabled:
			if value:
				zone_disabled.emit()
				active = false
			else:
				zone_enabled.emit()
		collision_shape.disabled = value


signal zone_activated()
signal zone_deactivated()

var active := false:
	get():
		return active
	set(value):
		if value != active:
			if value:
				zone_activated.emit()
			else:
				zone_deactivated.emit()
		active = value


func _on_chocomel_entered(body: Node3D) -> void:
	if disabled:
		return
	SignalBus.chocomel_entered_camera_magnet_zone.emit(self)


func _on_chocomel_exited(body: Node3D) -> void:
	SignalBus.chocomel_exited_camera_magnet_zone.emit(self)
