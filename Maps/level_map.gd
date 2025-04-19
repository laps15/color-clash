extends Node3D

@export var draw_viewport: PackedScene = preload("res://Draw/draw_viewport.tscn")
@export var custom_shader = preload("res://map_visual_shader.tres")
@export var calculate_color_score: bool = false

var mesh_viewport_map = {}
var child_meshes = {}

var color_score_thread: Thread
var color_score_semaphore: Semaphore
var hit_queue = []
var viewport_mutex = {}
var color_score = {}
var color_score_by_mesh = {}
var exit_thread = true

var mesh_to_texture_map = {
	"floor": "res://Maps/Resources/floor_texture.png",
	"box": "res://Maps/Resources/box_texture.png",
	"crate": "res://Maps/Resources/Wooden Crate_Crate_BaseColor.png",
}

func _exit_tree() -> void:
	if not multiplayer.is_server() or not self.calculate_color_score:
		return

	self.viewport_mutex["STOP_THREAD"].lock()
	self.exit_thread = true
	self.viewport_mutex["STOP_THREAD"].unlock()
	self.color_score_semaphore.post()

	self.color_score_thread.wait_to_finish()

func _ready():
	for child in self.find_children("*", "MeshInstance3D", true):
		self.init_mesh_properties(child as MeshInstance3D)

	if self.is_multiplayer_authority():
		ProcessProjectileCollisions.connect("map_hit", self.paint.rpc)

	if multiplayer.is_server() and self.calculate_color_score:
		self.color_score_thread = Thread.new()
		self.color_score_semaphore = Semaphore.new()
		self.viewport_mutex["STOP_THREAD"] = Mutex.new()
		self.viewport_mutex["SCORE_UPDATE"] = Mutex.new()
		self.exit_thread = false

		for mesh_unique_id in self.mesh_viewport_map:
			self.viewport_mutex[mesh_unique_id] = Mutex.new()
			self.color_score_by_mesh[mesh_unique_id] = {}

		self.color_score_thread.start(self._calculate_color_score)

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
	
	if multiplayer.is_server() and self.calculate_color_score:
		if not color in self.color_score[mesh_unique_id]:
			self.viewport_mutex[mesh_unique_id].lock()
			self.color_score_by_mesh[mesh_unique_id][color] = 0
			self.viewport_mutex[mesh_unique_id].unlock()
		
	#self.hit_queue.push_back(mesh_unique_id)
	#self.color_score_semaphore.post()

func get_color_at_pos(mesh_unique_id: int, pos: Vector2) -> Color:
	var viewPort = mesh_viewport_map[mesh_unique_id] as SubViewport
	var color = viewPort.get_texture().get_image().get_pixel(pos[0] * viewPort.size[0], pos[1] * viewPort.size[1])
	if color == Color(0,0,0,0):
		return Color.TRANSPARENT
	
	return color

func _calculate_color_score() -> void:
	while true:
		self.color_score_semaphore.wait()

		print("Semaphore post called")
		self.viewport_mutex["STOP_THREAD"].lock()
		if self.exit_thread:
			self.viewport_mutex["STOP_THREAD"].unlock()
			return
		self.viewport_mutex["STOP_THREAD"].unlock()
		
		var hit_to_process = hit_queue.pop_front()
		self.viewport_mutex[hit_to_process].lock()
		var color_score_before = self.color_score_by_mesh[hit_to_process].duplicate()
		var color_score_after = {}
		for color in color_score_before:
			color_score_after[color] = 0

		var viewport = self.mesh_viewport_map[hit_queue] as SubViewport
		var viewport_img = viewport.get_texture().get_image()

		for x in range(viewport.size[0]):
			for y in range(viewport.size[1]):
				var color = viewport_img.get_pixel(x,y)
				color_score_after[color] += 1
		self.viewport_mutex[hit_to_process].unlock()
		
		self.viewport_mutex["UPDATE_SCORE"].lock()
		for color in color_score_after:
			if not color in self.color_score:
				self.color_score[color] = 0
			self.color_score[color] += color_score_after[color] - color_score_before[color]
		self.viewport_mutex["UPDATE_SCORE"].unlock()
