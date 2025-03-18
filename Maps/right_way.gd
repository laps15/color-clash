extends MeshInstance3D
 
func _ready():
	UVPosition.set_mesh(self)
	(mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter("Paint", get_node('/root/Main/DrawViewport').get_texture())
