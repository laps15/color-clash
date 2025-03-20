extends CharacterBody3D
class_name Player

@onready var camera = $PlayerCamera
@onready var anim_player = $AnimationPlayer
@onready var paint_gun = $PlayerCamera/GunSlot/PaintGun
@onready var mesh_instance: MeshInstance3D = $Body
@onready var hud = $PlayerCamera/HUD

@export var color: Color

# Player stats
@export var current_hp = 2

const SPEED = 10.0
const JUMP_VELOCITY = 7.5

func _enter_tree() -> void:
	self.set_multiplayer_authority(str(self.name).to_int(), true)

func _ready() -> void:
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
		camera.rotate_x(-event.relative.y * .005)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
		
	if Input.is_action_just_pressed("reload") and not self.is_reloading():
			self.play_reload_effects.rpc()
			
	if Input.is_action_just_pressed("shoot") and not self.is_shooting() and not self.is_reloading():
			self.play_shoot_effects.rpc()

func _physics_process(delta: float) -> void:
	if not self.is_multiplayer_authority():
		return

	if current_hp == 0:
		return

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	if not self.is_shooting() and not self.is_reloading():
		anim_player.play( "Move" if input_dir != Vector2.ZERO and self.is_on_floor() else "Idle")

	move_and_slide()

func is_shooting():
	return anim_player.current_animation == "Shoot"
	
func is_reloading():
	return anim_player.current_animation == "Reload"

@rpc("call_local")
func play_shoot_effects() -> void:
	if paint_gun.can_shoot():
		anim_player.stop()
		anim_player.play("Shoot")
		
		paint_gun.shoot(str(self.name), self.color)

@rpc("call_local")
func play_reload_effects() -> void:
	print("Reloading...")
	anim_player.stop()
	anim_player.play("Reload")

@rpc("any_peer", "call_local")
func take_damage(target_path: NodePath, attacker_path: NodePath) -> void:
	if target_path != self.get_path():
		return

	self.set_current_hp.rpc(self.current_hp - 1)
	if current_hp == 0:
		if self.is_multiplayer_authority():
			self.get_node(attacker_path).increase_kill_count.rpc()
			hud.increase_death_count()
		self.die()
		hud.display_game_over(self)

@rpc("any_peer", "call_local")
func increase_kill_count() -> void:
	if self.is_multiplayer_authority():
		hud.increase_kill_count()

func die():
	print("On #", multiplayer.get_unique_id(), " die")
	if self.is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		self.remove_body.rpc()

@rpc("call_local")
func remove_body() -> void:
	self.hide()

func respawn() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	self.paint_gun.reload()
	self.set_current_hp(2)
	self.global_position = Vector3(randf_range(-10,10), 0, randf_range(-10, 10))
	self.reveal_body.rpc()

@rpc("call_local")
func reveal_body() -> void:
	self.show()

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Shoot":
		anim_player.play("Idle" )
	if anim_name == "Reload":
		paint_gun.reload()
		anim_player.play("Idle" )
