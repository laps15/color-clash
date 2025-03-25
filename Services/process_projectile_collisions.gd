extends Node

signal palyer_hit(hitter: String, hittee: String)
signal map_hit(mesh_path: NodePath, pos: Vector2, color: Color)

func process_collision(collision: KinematicCollision3D, hitter_id: int, color: Color) -> void:
		if not self.is_multiplayer_authority():
			return 

		var collision_target = collision.get_collider()
		if collision_target is CharacterBody3D:
			if not self.is_multiplayer_authority():
				return

			palyer_hit.emit(str(hitter_id), str(collision_target.name))
			return
		print(str("At #", multiplayer.get_unique_id(), " Detected hit at ", collision_target))
		var uv = UvPositionMultiMesh.get_uv_coords(collision_target.get_instance_id(), collision.get_position(), collision.get_normal(), true)
		if uv:
			map_hit.emit(collision_target.get_path(), uv, color)
