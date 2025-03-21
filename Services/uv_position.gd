extends Node

var meshtool_dict = {}
#var meshtool
var mesh_dict = {}
#var mesh
var mesh_instance_dict = {}
#var mesh_instance

var meshes

var transform_vertex_to_global = true

var _face_count_dict = {}
#var _face_count
var _world_normals_dict = {}
#var _world_normals :Array[Vector3] = []
var _world_vertices_dict = {}
#var _world_vertices := []
var _local_face_vertices_dict = {}
#var _local_face_vertices := []

func set_meshes(_meshes_dict):
	for id in _meshes_dict:
		mesh_instance_dict[id] = _meshes_dict[id]
		mesh_dict[id] = _meshes_dict[id].mesh
		meshtool_dict[id] = MeshDataTool.new()
		meshtool_dict[id].create_from_surface(mesh_dict[id], 0)  
		
		_face_count_dict[id] = meshtool_dict[id].get_face_count()
		_world_normals_dict[id] = Array([], TYPE_VECTOR3, "Vector3", null)
		_world_normals_dict[id].resize(_face_count_dict[id])
		_world_vertices_dict[id] = []
		_local_face_vertices_dict[id] = []
  
		_load_mesh_data(id)
  
func _resize_pools():
	pass

func _load_mesh_data(mesh_unique_id: int):
	for idx in range(_face_count_dict[mesh_unique_id]):
		_world_normals_dict[mesh_unique_id][idx] = mesh_instance_dict[mesh_unique_id].global_transform.basis * meshtool_dict[mesh_unique_id].get_face_normal(idx)
	
		var fv1 = meshtool_dict[mesh_unique_id].get_face_vertex(idx, 0)
		var fv2 = meshtool_dict[mesh_unique_id].get_face_vertex(idx, 1)
		var fv3 = meshtool_dict[mesh_unique_id].get_face_vertex(idx, 2)
		
		_local_face_vertices_dict[mesh_unique_id].append([fv1, fv2, fv3])    
		
		_world_vertices_dict[mesh_unique_id].append([
			mesh_instance_dict[mesh_unique_id].global_transform.basis * meshtool_dict[mesh_unique_id].get_vertex(fv1),
			mesh_instance_dict[mesh_unique_id].global_transform.basis * meshtool_dict[mesh_unique_id].get_vertex(fv2),
			mesh_instance_dict[mesh_unique_id].global_transform.basis * meshtool_dict[mesh_unique_id].get_vertex(fv3),
		])
	
func get_face(mesh_unique_id: int, point, normal, epsilon = 0.1) -> Array:
	var matches = []
	for idx in range(_face_count_dict[mesh_unique_id]):
		var world_normal = _world_normals_dict[mesh_unique_id][idx]
	
		if !equals_with_epsilon(world_normal, mesh_instance_dict[mesh_unique_id].global_transform.basis * normal, epsilon):
			continue  
		var vertices = _world_vertices_dict[mesh_unique_id][idx]    
		
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

func get_uv_coords(mesh_unique_id: int, point, normal, transform = true):
	# Gets the uv coordinates on the mesh given a point on the mesh and normal
	# these values can be obtained from a raycast
	transform_vertex_to_global = transform
  
	if not mesh_unique_id in meshtool_dict:
		return null

	var face = get_face(mesh_unique_id, point, normal)
	if face.size() < 3:
		return null
	face = face as Array
	var bc = face[2]
	
	var uv1 = meshtool_dict[mesh_unique_id].get_vertex_uv(_local_face_vertices_dict[mesh_unique_id][face[0]][0])
	var uv2 = meshtool_dict[mesh_unique_id].get_vertex_uv(_local_face_vertices_dict[mesh_unique_id][face[0]][1])
	var uv3 = meshtool_dict[mesh_unique_id].get_vertex_uv(_local_face_vertices_dict[mesh_unique_id][face[0]][2])
  
	return (uv1 * bc.x) + (uv2 * bc.y) + (uv3 * bc.z)  

func equals_with_epsilon(v1: Vector3, v2: Vector3, epsilon):
	if (v1.distance_to(v2) < epsilon):
		return true
	return false
  
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

func transfer_point(from : Basis, to : Basis, point : Vector3) -> Vector3:
	return (to * from.inverse()) * point
  
func bary2cart(a : Vector3, b : Vector3, c: Vector3, barycentric: Vector3) -> Vector3:
	return barycentric.x * a + barycentric.y * b + barycentric.z * c
  
func is_point_in_triangle(point, v1, v2, v3):
	var bc = cart2bary(point, v1, v2, v3)  
  
	if (bc.x < 0 or bc.x > 1) or (bc.y < 0 or bc.y > 1) or (bc.z < 0 or bc.z > 1):
		return null

	return bc
