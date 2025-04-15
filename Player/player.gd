extends CharacterBody3D
class_name Player

enum PlayerMode {HUMANOID, BALL}

@export var anim_player: AnimationPlayer
@export var uncrouch_shape_cast: ShapeCast3D
@export var camera_pivot: Node3D
@export var camera: Camera3D
@export var paint_gun: Node3D
@export var gun_slot: Node3D
@export var hud: CanvasLayer

# Humanoid exported vars
@export var humanoid_hit_box: CollisionShape3D
@export var humanoid_mesh_instance: MeshInstance3D

# Ball exported vars
@export var ball_hit_box: CollisionShape3D
@export var ball_mesh_instance: MeshInstance3D
@export var ray_checker: Node3D
# Configs
@export_range(0.001, 0.5) var mouse_sensivity = 0.005
@export_range(-15, 15) var camera_to_gun_adjustment = -1.5

# Player stats
@export var current_hp = 2
@export var is_crouched: bool = false
@export var player_mode: PlayerMode = PlayerMode.HUMANOID
var player_name: String

@onready var level_map = $/root/Game/Level

@export var color: Color

const CROUCH_SPEED = 7.0
const SPEED = 10.0
const JUMP_VELOCITY = 7.5
const GRAVITY_SPEED = 9.8

const MOTION_INTERPOLATION_SPEED = 10
const ROTATION_INTERPOLATION_SPEED = 10
const ACCELERATION = 10

var started_fall = null
var move_speed_modifier = 1.
var movement_disabled = false

# ball mode vars
var gravity: Vector3 = Vector3.DOWN * GRAVITY_SPEED
var orientation = Transform3D()
var motion = Vector2()
var vertical_velocity: Vector3 = Vector3.ZERO
var attached_to: StaticBody3D

func _enter_tree() -> void:
	self.set_multiplayer_authority(str(self.name).to_int(), true)

func _ready() -> void:
	self.uncrouch_shape_cast.add_exception(self)
	
	var material = StandardMaterial3D.new()
	material.albedo_color = self.color
	self.humanoid_mesh_instance.set_surface_override_material(0, material)
	self.ball_mesh_instance.set_surface_override_material(0, material)

	self.ball_mesh_instance.hide()
	self.ball_hit_box.disabled = true
	
	if not self.is_multiplayer_authority():
		return

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	self.hud.set_player_name(self.player_name)

func set_color(new_color: Color) -> void:
	self.color = new_color

func set_current_hp(new_current_hp: int) -> void:
	self.current_hp = new_current_hp
	self.hud.update_hp.rpc(self.current_hp)

@rpc("call_local")
func transform_into():
	self.player_mode = PlayerMode.BALL
	self.humanoid_hit_box.disabled = true
	self.gun_slot.hide()
	self.humanoid_mesh_instance.hide()
	
	self.ball_hit_box.disabled = false
	self.ball_mesh_instance.show()

@rpc("call_local")
func transform_out():
	self.player_mode = PlayerMode.HUMANOID
	self.ball_hit_box.disabled = true
	self.ball_mesh_instance.hide()
	
	self.humanoid_hit_box.disabled = false
	self.humanoid_mesh_instance.show()
	self.gun_slot.show()
	
	self.up_direction = Vector3.UP
	self.gravity = Vector3.DOWN * GRAVITY_SPEED
	self.orientation = Transform3D()
	self.motion = Vector2()
	self.vertical_velocity = Vector3.ZERO
	self.attached_to = null

func _unhandled_input(event: InputEvent) -> void:
	if not self.is_multiplayer_authority():
		return

	# Input handling common to both modes
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensivity)
		self.camera_pivot.rotate_x(-event.relative.y * mouse_sensivity)
		self.camera_pivot.rotation.x = clamp(self.camera_pivot.rotation.x, -PI/2, PI/2)

	match self.player_mode:
		PlayerMode.HUMANOID:
			self._unhandled_humanoid_input(event)
		PlayerMode.BALL:
			self._unhandled_ball_input(event)

func _unhandled_humanoid_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		self.gun_slot.rotate_x(-event.relative.y * mouse_sensivity * 0.5)
		self.gun_slot.rotation.x = clamp(self.gun_slot.rotation.x, -PI/4, PI/4)

	if Input.is_action_just_pressed("crouch"):
		self.transform_into.rpc()
		return

	if Input.is_action_just_pressed("reload") and not self.is_reloading():
		self.play_reload_effects.rpc()
	if Input.is_action_just_pressed("shoot") and not self.is_shooting() and not self.is_reloading():
		self.play_shoot_effects.rpc()

func _unhandled_ball_input(_event: InputEvent) -> void:
	if Input.is_action_just_released("crouch"):
		self.transform_out.rpc()

func _physics_process(delta: float) -> void:
	if not self.is_multiplayer_authority():
		return

	if movement_disabled:
		return

	match self.player_mode:
		PlayerMode.HUMANOID:
			self._physics_process_humanoid(delta)
		PlayerMode.BALL:
			self._physics_process_ball(delta)

func _physics_process_humanoid(delta: float) -> void:
	if not self.is_multiplayer_authority():
		return

	if movement_disabled:
		return

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Add the gravity.
	if not self.movement_disabled and not self.is_on_floor():
		if not started_fall:
			started_fall = Time.get_ticks_msec()
		#elif Time.get_ticks_msec() - self.started_fall > 5000:
			#self.die()
			#return

		velocity += get_gravity() * delta
	else:
		started_fall = null

	if direction:
		velocity.x = direction.x * SPEED * move_speed_modifier 
		velocity.z = direction.z * SPEED * move_speed_modifier
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * move_speed_modifier)
		velocity.z = move_toward(velocity.z, 0, SPEED * move_speed_modifier)

	self.move_and_slide()

func _physics_process_ball(delta: float) -> void:
	var input_dir := Input.get_vector("left", "right", "up", "down")

	self.check_rays()

	# Add the gravity.	
	if not self.is_on_floor():
		self.vertical_velocity += self.gravity * delta
	else:
		self.vertical_velocity = Vector3.ZERO

	self._process_input(input_dir, delta)

func check_rays():
	var new_avg = self.ray_checker.get_avg_normal() as Vector3
	if new_avg and new_avg != self.up_direction:
		self.up_direction = new_avg
		self.gravity = (-self.up_direction) * GRAVITY_SPEED
	elif not new_avg:
		self.up_direction = Vector3.UP
		self.gravity = (-self.up_direction) * GRAVITY_SPEED

func _process_input(input_dir: Vector2, delta: float) -> void:
	self.motion = self.motion.lerp(input_dir, self.MOTION_INTERPOLATION_SPEED * delta)
	
	var camera_basis = self.camera.global_transform.basis
	var camera_z = camera_basis.z
	var camera_x = camera_basis.x
	
	camera_z = camera_z.normalized()
	camera_x = camera_x.normalized()
	
	# Handle jump.
	if Input.is_action_just_pressed("jump"): # and is_on_floor():
		var jump_speed = self.JUMP_VELOCITY if self.up_direction == Vector3.UP else 0.5 * self.JUMP_VELOCITY
		self.vertical_velocity += self.up_direction * jump_speed
		self.up_direction = Vector3.UP
		self.gravity = Vector3.DOWN * self.GRAVITY_SPEED

	var player_look_at = camera_x * self.motion.x + camera_z * self.motion.y
	
	if self.ball_mesh_instance.rotation.y < -PI/2 or self.ball_mesh_instance.rotation.y > PI/2:
		player_look_at.y = -player_look_at.y
	
	if player_look_at.length() > 0.001:
		var q_from = orientation.basis.get_rotation_quaternion()
		var q_to = Transform3D().looking_at(player_look_at, self.up_direction).basis
		
		orientation.basis = Basis(q_from.slerp(q_to, self.ROTATION_INTERPOLATION_SPEED * delta))

	var horizontal_velocity = velocity

	var color_speed_modifier = self.get_color_speed_modifier()
	var direction = (camera_basis * Vector3(self.motion.x, 0, self.motion.y))
	var position_target = direction * self.SPEED * color_speed_modifier
	
	if direction.length() < 0.001:
		horizontal_velocity = Vector3.ZERO
	else:
		horizontal_velocity = horizontal_velocity.lerp(position_target, ACCELERATION * delta)

	# Negate velocity on normal direction
	var normal_squared = self.up_direction.dot(self.up_direction)
	var velocity_on_normal = horizontal_velocity.dot(self.up_direction) / normal_squared * self.up_direction
	horizontal_velocity -= velocity_on_normal
	
	velocity = horizontal_velocity + self.vertical_velocity

	move_and_slide()

	self.orientation.origin = Vector3()
	self.orientation = self.orientation.orthonormalized()
	self.ball_mesh_instance.global_transform.basis = self.orientation.basis

func get_color_speed_modifier() -> float:
	match get_color_on_direction(Vector3.DOWN):
		-1:
			return 0.5
		1:
			return 1.5
	return 1.

func get_color_on_direction(direction: Vector3):
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)

		var collision_target = collision.get_collider()
		if collision_target is CharacterBody3D or !UvPositionMultiMesh.equals_with_epsilon(collision.get_normal(), (direction * -1), 0.1):
			continue

		var uv = UvPositionMultiMesh.get_uv_coords(collision_target.get_instance_id(), collision.get_position(), collision.get_normal(), true)
		if uv == null:
			continue

		var color_on_map = level_map.get_color_at_pos(collision_target.get_instance_id(), uv)
		if color_on_map == self.color:
			return 1
		elif color_on_map != Color.TRANSPARENT:
			return -1
	return 0

func is_shooting():
	return anim_player.current_animation == "Shoot"

func is_reloading():
	return anim_player.current_animation == "Reload"

@rpc("call_local")
func play_shoot_effects() -> void:
	if paint_gun.can_shoot():
		#anim_player.play("Shoot")
		paint_gun.shoot(str(self.name), self.color)

@rpc("call_local")
func play_reload_effects() -> void:
	anim_player.stop()
	anim_player.play("Reload")

@rpc("any_peer", "call_local")
func take_damage(attacker_path: NodePath) -> void:
	self.set_current_hp(self.current_hp - 1)
	if current_hp == 0:
		self.die(attacker_path)
		if self.is_multiplayer_authority():
			self.get_node(attacker_path).increase_kill_count.rpc()
			hud.increase_death_count()
		self.die()
		hud.display_game_over(self)

@rpc("any_peer", "call_local")
func increase_kill_count() -> void:
	if self.is_multiplayer_authority():
		hud.increase_kill_count()

func die(attacker_path: NodePath = ""):
	if not self.is_multiplayer_authority():
		return

	self.movement_disabled = true
	self.set_current_hp(0)
	print("On #", multiplayer.get_unique_id(), " die")
	hud.increase_death_count()
	if attacker_path != NodePath(""):
		self.get_node(attacker_path).increase_kill_count.rpc()
	hud.display_game_over(self)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	self.remove_body.rpc()

@rpc("call_local")
func remove_body() -> void:
	self.humanoid_hit_box.disabled = true
	self.hide()

func respawn() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	self.paint_gun.reload()
	self.set_current_hp(2)
	self.started_fall = null
	self.is_crouched = false
	self.global_position = Vector3(randf_range(-10,10), 0, randf_range(-10, 10))
	self.reveal_body.rpc()
	self.movement_disabled = false

@rpc("call_local")
func reveal_body() -> void:
	self.humanoid_hit_box.disabled = false
	self.show()

@rpc("call_local")
func crouch():
	if not self.is_crouched:
		self.anim_player.play("Crouch", -1, CROUCH_SPEED)

@rpc("call_local")
func uncrouch():
	if self.is_crouched and not self.uncrouch_shape_cast.is_colliding():
		self.anim_player.play("Crouch", -1, -CROUCH_SPEED, true)
	elif self.is_crouched and not Input.is_action_pressed("crouch"):
		await get_tree().create_timer(0.1).timeout
		self.uncrouch.rpc()

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	#if anim_name == "Shoot":
		#anim_player.play("Idle")

	if anim_name == "Reload":
		paint_gun.reload()
		#anim_player.play("Idle")
		#
	#if anim_name == "Crouch":
		#if not self.is_crouched:
			#anim_player.play("Idle")

func _on_animation_player_animation_started(anim_name: StringName) -> void:
	if anim_name == "Crouch":
		self.is_crouched = !self.is_crouched
