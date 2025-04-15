extends Node3D

@export var draw_viewport: PackedScene = preload("res://Draw/draw_viewport.tscn")
@export var custom_shader = preload("res://map_visual_shader.tres")

var mesh_viewport_map = {}
var child_meshes = {}

var mesh_to_texture_map = {
	"floor": "res://Maps/Resources/floor_texture.png",
	"box": "res://Maps/Resources/box_texture.png",
	"crate": "res://Maps/Resources/Wooden Crate_Crate_BaseColor.png",
}

func _ready():
	for child in self.find_children("*", "MeshInstance3D", true):
		self.init_mesh_properties(child as MeshInstance3D)

	if self.is_multiplayer_authority():
		ProcessProjectileCollisions.connect("map_hit", self.paint.rpc)

func init_mesh_properties(mesh_instance: MeshInstance3D):
	var static_body = mesh_instance.get_node("StaticBody3D")
	if not static_body:
		return
		
	var mesh_unique_id = static_body.get_instance_id()
	UvPositionMultiMesh.set_mesh(mesh_instance, mesh_unique_id)
	
	var shader_texture = load(self.mesh_to_texture_map[mesh_instance.name]) as CompressedTexture2D

	var viewport = (draw_viewport.instantiate() as SubViewport)
	viewport.size = Vector2i(shader_texture.get_width(), shader_texture.get_height())
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	mesh_viewport_map[mesh_unique_id] = viewport
	
	var shader_material = ShaderMaterial.new()
	shader_material.shader = custom_shader
	shader_material.set_shader_parameter("Texture", load(self.mesh_to_texture_map[mesh_instance.name]))
	shader_material.set_shader_parameter("Paint", viewport.get_texture())
	mesh_instance.mesh.surface_set_material(0, shader_material)
	
	child_meshes[mesh_unique_id] = mesh_instance
	self.add_child(viewport)

@rpc("call_local")
func paint(mesh_path: NodePath, pos: Vector2, color: Color = Color.RED):
	var node = self.get_node(mesh_path)
	var mesh_unique_id = node.get_instance_id()
	var viewport_size = mesh_viewport_map[mesh_unique_id].size
	var converted_pos = Vector2(pos[0] * viewport_size[0], pos[1] * viewport_size[1])
	mesh_viewport_map[mesh_unique_id].paint(converted_pos, color)


func get_color_at_pos(mesh_unique_id: int, pos: Vector2) -> Color:
	var viewPort = mesh_viewport_map[mesh_unique_id] as SubViewport
	var color = viewPort.get_texture().get_image().get_pixel(pos[0] * viewPort.size[0], pos[1] * viewPort.size[1])
	if color == Color(0,0,0,0):
		return Color.TRANSPARENT
	
	return color
