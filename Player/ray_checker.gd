extends Node3D

@onready var level_map = $/root/Game/Level

func get_avg_normal(_target_color: Color = Color.TRANSPARENT) -> Vector3:
	var avg := Vector3.ZERO
	var amount := 0
	
	for ray in self.get_children():
		ray = (ray as RayCast3D)
		if ray.is_colliding():
			var collision_normal = ray.get_collision_normal()
			amount += 1
			avg += collision_normal
			#var collision_target = ray.get_collider()
			#var uv = UvPositionMultiMesh.get_uv_coords(collision_target.get_instance_id(), ray.get_collision_point(), collision_normal, true)
			#if uv == null:
				#continue
#
			#var color = level_map.get_color_at_pos(collision_target.get_instance_id(), uv)
			#if color == target_color:
				#amount += 1
				#avg += collision_normal

	if amount:
		return (avg / amount).normalized()
	
	return avg
