extends Node3D

@export var paint_scene: PackedScene

var rng = RandomNumberGenerator.new()

func shoot(color: Color) -> void:
	var p = paint_scene.instantiate() as PaintBlob
	p.color = color
	self.add_child(p)
	p.global_position = self.global_position
	p.global_rotation = self.global_rotation
	
	p.set_start_velocity()
