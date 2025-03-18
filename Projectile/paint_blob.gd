extends CharacterBody3D
class_name PaintBlob

@export var color: Color = Color.YELLOW_GREEN
@export var speed = 50.0

@onready var level_map = $"/root/Main/Level"
@onready var mesh_instance = $Mesh

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	self.mesh_instance.set_surface_override_material(0, material)

func set_start_velocity():
	print(str(global_transform.basis, "*" , Vector3.FORWARD, ") * ", self.speed))
	self.velocity = (global_transform.basis * Vector3.FORWARD).normalized() * self.speed;
	
func _physics_process(delta: float) -> void:
	self.velocity.y -= gravity * delta
	self.look_at(self.position + self.velocity)

	self.move_and_slide()

	var slide_collision_count = self.get_slide_collision_count()
	if slide_collision_count > 0:
		for i in range(slide_collision_count):
			var collision = self.get_slide_collision(i)
			var collision_target = collision.get_collider()
			if collision_target is CharacterBody3D:
				(collision_target as Player).take_damage.rpc_id(str(collision_target.name).to_int())
				continue
			print(str("Hit at ", collision_target))
			var uv = UVPosition.get_uv_coords(collision_target.get_instance_id(), collision.get_position(), collision.get_normal(), true)
			if uv:
				level_map.paint(collision_target.get_instance_id(), uv, color)
		self.queue_free()
