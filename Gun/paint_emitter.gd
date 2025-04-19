extends Node3D

@export var paint_scene: PackedScene

@onready var projectiles = $"/root/Game/Projectiles"

var rng = RandomNumberGenerator.new()

func shoot(color: Color, peer_id: String) -> void:
	var p = paint_scene.instantiate() as PaintBlob
	p.color = color
	p.set_peer_id(peer_id)
	self.projectiles.add_child(p)
	p.global_position = self.global_position
	p.global_rotation = self.global_rotation
	
	p.set_start_velocity()
