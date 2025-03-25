extends Node

# Store meshes in a dictionary indexed by instance_id
var meshes = {}

var transform_vertex_to_global = true

func set_mesh(_mesh_instance: MeshInstance3D, instance_id):
	var parent = _mesh_instance.get_parent_node_3d()
	meshes[instance_id] = {
		"mesh_instance": _mesh_instance,
		"mesh": _mesh_instance.mesh,
		"meshtool": MeshDataTool.new(),
		"face_count": 0,
		"world_normals": [],
		"world_vertices": [],
		"local_face_vertices": [],
		"to_global": _mesh_instance.to_global,
	}
	
	# Initialize mesh data for the current instance
	var instance_data = meshes[instance_id]
	instance_data["meshtool"].create_from_surface(instance_data["mesh"], 0)
	instance_data["face_count"] = instance_data["meshtool"].get_face_count()
	instance_data["world_normals"].resize(instance_data["face_count"])
  
	_load_mesh_data(instance_id)

func _load_mesh_data(instance_id):
	var instance_data = meshes[instance_id]
	var transform = instance_data["mesh_instance"].global_transform

	for idx in range(instance_data["face_count"]):
		instance_data["world_normals"][idx] = (transform.basis * instance_data["meshtool"].get_face_normal(idx)).normalized()
	
		var fv1 = instance_data["meshtool"].get_face_vertex(idx, 0)
		var fv2 = instance_data["meshtool"].get_face_vertex(idx, 1)
		var fv3 = instance_data["meshtool"].get_face_vertex(idx, 2)
		
		instance_data["local_face_vertices"].append([fv1, fv2, fv3])    
		
		instance_data["world_vertices"].append([
			instance_data["to_global"].call(instance_data["meshtool"].get_vertex(fv1)),
			instance_data["to_global"].call(instance_data["meshtool"].get_vertex(fv2)),
			instance_data["to_global"].call(instance_data["meshtool"].get_vertex(fv3)),
		])

func get_face(instance_id: int, point, normal, epsilon = 0.1) -> Array:
	var instance_data = meshes.get(instance_id)
	if not instance_data:
		return []
	
	var matches = []
	for idx in range(instance_data["face_count"]):
		var world_normal = instance_data["world_normals"][idx]
	
		if !equals_with_epsilon(world_normal, normal, epsilon):
			continue  
		var vertices = instance_data["world_vertices"][idx]    
		
		var bc = is_point_in_triangle(point, vertices[0], vertices[1], vertices[2])    
		if bc:
			matches.push_back([idx, vertices, bc])
	
	if matches.size() > 1:
		var closest_match
		var smallest_distance = 99999.0
		for m in matches:
			var plane := Plane(m[1][0], m[1][1], m[1][2])
			var dist = absf(plane.distance_to(point))
			if dist < smallest_distance:
				smallest_distance = dist
				closest_match = m
		return closest_match
		
	if matches.size() > 0:
		return matches[0]
	
	return []

func get_uv_coords(instance_id: int, point, normal, transform = true):
	# Gets the UV coordinates on the mesh given a point on the mesh and normal
	transform_vertex_to_global = transform

	var face = get_face(instance_id, point, normal)

	if face.size() < 3:
		return null

	var instance_data = meshes[instance_id]
	var bc = face[2]
	
	var uv1 = instance_data["meshtool"].get_vertex_uv(instance_data["local_face_vertices"][face[0]][0])
	var uv2 = instance_data["meshtool"].get_vertex_uv(instance_data["local_face_vertices"][face[0]][1])
	var uv3 = instance_data["meshtool"].get_vertex_uv(instance_data["local_face_vertices"][face[0]][2])

	return bary2cart(uv1, uv2, uv3, bc)

func equals_with_epsilon(v1, v2, epsilon):
	return v1.distance_to(v2) < epsilon
  
func cart2bary(p : Vector3, a : Vector3, b : Vector3, c: Vector3) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var d20 := v2.dot(v0)
	var d21 := v2.dot(v1)
	var denom := d00 * d11 - d01 * d01
	var v = (d11 * d20 - d01 * d21) / denom
	var w = (d00 * d21 - d01 * d20) / denom
	var u = 1.0 - v - w
	return Vector3(u, v, w)

func bary2cart(a : Vector2, b : Vector2, c: Vector2, barycentric: Vector3) -> Vector2:
	return barycentric.x * a + barycentric.y * b + barycentric.z * c
  
func is_point_in_triangle(point, v1, v2, v3):
	var bc = cart2bary(point, v1, v2, v3)  
	
	if (bc.x < 0 or bc.x > 1) or (bc.y < 0 or bc.y > 1) or (bc.z < 0 or bc.z > 1):
		return null

	return bc
