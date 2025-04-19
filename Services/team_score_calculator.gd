extends Node
class_name TeamScoreCalculator

var textures_map = {}

var color_score_thread: Thread
var semaphore: Semaphore
var mutexes = {}
var color_score = {}
var exit_thread = false
var player_colors = []
var score_queue = []

func set_player_colors(colors: Array) -> void:
	self.player_colors = colors
	self.color_score = {}
	for color in player_colors:
		color_score[color] = 0
	
func init_texture_map(mesh_viewport_map: Variant) -> void:
	for mesh_id in mesh_viewport_map:
		self.textures_map[mesh_id] = mesh_viewport_map[mesh_id].get_texture()

func _exit_tree() -> void:
	if not multiplayer.is_server():
		return

	(self.mutexes["QUIT"] as Mutex).lock()
	self.exit_thread = true
	(self.mutexes["QUIT"] as Mutex).unlock()
	self.semaphore.post()
	
	self.color_score_thread.wait_to_finish()

func _ready():
	print("Team Score Calculator _ready")
	if not multiplayer.is_server():
		return

	self.semaphore = Semaphore.new()
	self.mutexes["QUIT"] = Mutex.new()
	self.mutexes["SCORE"] = Mutex.new()
	self.color_score_thread = Thread.new()
	self.color_score_thread.start(self.calculate_score)
	print("Connecting map_hit")
	ProcessProjectileCollisions.map_hit.connect(self.queue_score_calculation)

func get_score_by_mesh(mesh_id: int) -> Variant:
	var score = {}
	for color in player_colors:
		score[color] = 0

	var texture_image = (self.textures_map[mesh_id] as ViewportTexture).get_image()

	for y in range(texture_image.get_height()):
		for x in range(texture_image.get_width()):
			var color = texture_image.get_pixel(y,x)
			if color in score:
				score[color] += 1
	
	return score

func calculate_score() -> void:
	print("SCORE: ", self.color_score)
	var score_by_mesh = {}
	for mesh_id in self.textures_map:
		score_by_mesh[mesh_id] = {}
		for color in player_colors:
			score_by_mesh[mesh_id][color] = 0

	while true:
		self.semaphore.wait()
		
		var mesh_id = self.score_queue.pop_front()
		
		(self.mutexes["QUIT"] as Mutex).lock()
		if self.exit_thread:
			(self.mutexes["QUIT"] as Mutex).unlock()
			return
		(self.mutexes["QUIT"] as Mutex).unlock()

		var new_score_for_mesh = get_score_by_mesh(mesh_id)

		(self.mutexes["SCORE"] as Mutex).lock()
		for color in color_score:
			self.color_score[color] += new_score_for_mesh[color] - score_by_mesh[mesh_id][color]
		score_by_mesh[mesh_id] = new_score_for_mesh
		(self.mutexes["SCORE"] as Mutex).unlock()

		print("SCORE: ", self.color_score)

func queue_score_calculation(mesh_path: NodePath, _pos: Vector2, _color: Color):
	print("Queueing score calculation")
	await RenderingServer.frame_post_draw
	self.score_queue.push_back(self.get_node(mesh_path).get_instance_id())
	self.semaphore.post()

func get_score(color: Color) -> int:
	print("Queueing score calculation")
	var score = 0
	(self.mutexes["SCORE"] as Mutex).lock()
	if color in self.color_score:
		score = self.color_score[color]
	(self.mutexes["SCORE"] as Mutex).unlock()
	return score
