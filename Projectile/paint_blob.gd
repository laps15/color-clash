extends CharacterBody3D
class_name PaintBlob

@export var color: Color = Color.YELLOW_GREEN
@export var speed = 50.0

@onready var level_map = $"/root/Main/Level"
@onready var mesh_instance = $Mesh

@export var peer_id: String

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var spawned_at = null

func _ready() -> void:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	self.mesh_instance.set_surface_override_material(0, material)
	self.spawned_at = Time.get_ticks_msec()

func set_start_velocity():
	self.velocity = (global_transform.basis * Vector3.FORWARD).normalized() * self.speed;
	
func set_peer_id(new_peer_id: String) -> void:
	self.peer_id = str(new_peer_id)
	
func _physics_process(delta: float) -> void:
	if Time.get_ticks_msec() - self.spawned_at > 5000:
		self.queue_free()

	self.velocity.y -= gravity * delta
	self.look_at(self.position + self.velocity)

	self.move_and_slide()

	var slide_collision_count = self.get_slide_collision_count()
	if slide_collision_count > 0:
		for i in range(slide_collision_count):
			var collision = self.get_slide_collision(i)
			ProcessProjectileCollisions.process_collision(collision, str(self.peer_id).to_int(), self.color)
		self.queue_free()
