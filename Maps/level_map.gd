extends Node3D

@export var draw_viewport: PackedScene = preload("res://Draw/draw_viewport.tscn")

var mesh_viewport_map = {}
var child_meshes = {}

func _ready():
	for child in self.find_children("*", "MeshInstance3D", true):
		var child_mesh = (child as MeshInstance3D)
		var mesh_texture = (child_mesh.mesh.surface_get_material(0) as ShaderMaterial).get_shader_parameter("Texture") as CompressedTexture2D
		var mesh_unique_id = child_mesh.get_node("StaticBody3D").get_instance_id()
		print(str(child_mesh.name, " ", mesh_unique_id, " ", mesh_texture.get_image()))
		
		var viewport = (draw_viewport.instantiate() as SubViewport)
		viewport.size = Vector2i(mesh_texture.get_width(), mesh_texture.get_height())
		viewport.transparent_bg = true
		viewport.handle_input_locally = false
		mesh_viewport_map[mesh_unique_id] = viewport
		
		child_meshes[mesh_unique_id] = child_mesh
		self.add_child(viewport)

	UVPosition.set_meshes(child_meshes)
	for mesh_unique_id in child_meshes:
		(child_meshes[mesh_unique_id].mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter("Paint", mesh_viewport_map[mesh_unique_id].get_texture())
		
	print(str("We currently have ", len(mesh_viewport_map), " viewports instantiated"))
	for mesh_unique_id in mesh_viewport_map:
		print(str("Viewport #", mesh_unique_id, " size: (", mesh_viewport_map[mesh_unique_id].size[0], ", ", mesh_viewport_map[mesh_unique_id].size[1], ")"))

func paint(mesh_unique_id: int, pos: Vector2, color: Color = Color.RED):
	print(str("Painting at ", mesh_unique_id, "(", pos[0], ", ", pos[1], ")"))
	var viewport_size = mesh_viewport_map[mesh_unique_id].size
	var converted_pos = Vector2(pos[0] * viewport_size[0], pos[1] * viewport_size[1])
	mesh_viewport_map[mesh_unique_id].paint(converted_pos, color)
