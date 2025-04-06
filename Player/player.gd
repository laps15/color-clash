extends CharacterBody3D
class_name Player


@export var anim_player: AnimationPlayer
@export var uncrouch_shape_cast: ShapeCast3D
@export var mesh_instance: MeshInstance3D
@export var camera: Camera3D
@export var paint_gun: Node3D
@export var gun_slot: Node3D
@export var hit_box: CollisionShape3D
@export var hud: CanvasLayer

# Player stats
@export var current_hp = 2
@export var is_crouched: bool = false

@onready var level_map = $/root/Main/Level

@export var color: Color

var started_fall = null
var move_speed_modifier = 1.
var movement_disabled = false

const CROUCH_SPEED = 7.0
const SPEED = 10.0
const JUMP_VELOCITY = 7.5

func _enter_tree() -> void:
	self.set_multiplayer_authority(str(self.name).to_int(), true)

func _ready() -> void:
	self.uncrouch_shape_cast.add_exception(self)
	
	var material = StandardMaterial3D.new()
	material.albedo_color = self.color
	self.mesh_instance.set_surface_override_material(0, material)
	
	if not self.is_multiplayer_authority():
		return

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true

func set_color(color: Color) -> void:
	self.color = color

@rpc("call_local")
func set_current_hp(current_hp: int) -> void:
	self.current_hp = current_hp
	self.hud.update_hp.rpc(self.current_hp)

func _unhandled_input(event: InputEvent) -> void:
	if not self.is_multiplayer_authority():
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * .005)
		self.camera.rotate_x(-event.relative.y * .005)
		self.camera.rotation.x = clamp(camera.rotation.x, -PI/4, PI/4)
		print("Event: ", -event.relative.y * .005)
		print("Rotation b4: ", self.gun_slot.rotation.x)
		self.gun_slot.rotate_x(-event.relative.y * .005)
		self.gun_slot.rotation.x = clamp(self.gun_slot.rotation.x, -PI/4, PI/4)
		print("Rotation after: ", self.gun_slot.rotation)

	if Input.is_action_just_pressed("crouch"):
		self.crouch.rpc()
	if Input.is_action_just_released("crouch"):
		self.uncrouch.rpc()

	if self.is_crouched:
		return

	if Input.is_action_just_pressed("reload") and not self.is_reloading():
		self.play_reload_effects.rpc()
	if Input.is_action_just_pressed("shoot") and not self.is_shooting() and not self.is_reloading():
		self.play_shoot_effects.rpc()

func _physics_process(delta: float) -> void:
	if not self.is_multiplayer_authority():
		return

	if movement_disabled:
		return

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if is_on_floor() or is_on_wall():
		move_speed_modifier = self.get_color_speed_modifier()
		if is_crouched:
			move_speed_modifier *= 0.5

	# Add the gravity.
	if not self.movement_disabled and not self.is_on_floor():
		if not started_fall:
			started_fall = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - self.started_fall > 5000:
			self.die()
			return

		velocity += get_gravity() * delta
	else:
		started_fall = null

	if direction:
		velocity.x = direction.x * SPEED * move_speed_modifier 
		velocity.z = direction.z * SPEED * move_speed_modifier
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * move_speed_modifier)
		velocity.z = move_toward(velocity.z, 0, SPEED * move_speed_modifier)

	#if self.is_idle() and input_dir != Vector2.ZERO:
		#anim_player.play("Move", -1, 2.0)
	#elif self.is_moving() and input_dir == Vector2.ZERO:
		#anim_player.play("Idle")

	self.move_and_slide()

func is_idle_or_moving() -> bool:
	return not self.is_shooting() and not self.is_reloading() and not (self.is_crouched or is_crouching())

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

		var color = level_map.get_color_at_pos(collision_target.get_instance_id(), uv)
		if color == self.color:
			return 1
		elif color != Color.TRANSPARENT:
			return -1
	return 0

func is_crouching():
	return anim_player.current_animation == "Crouch"

func is_idle():
	return anim_player.current_animation == "Idle"

func is_moving():
	return anim_player.current_animation == "Move"

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
func take_damage(target_path: NodePath, attacker_path: NodePath) -> void:
	if target_path != self.get_path():
		return

	self.set_current_hp.rpc(self.current_hp - 1)
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
	self.hit_box.disabled = true
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
	self.hit_box.disabled = false
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
