extends Node

@export var current_level: PackedScene
@export var left_spawn_point_list: Node
@export var right_spawn_point_list: Node
@export var spawner: MultiplayerSpawner
@export var players_node: Node
@export var map: Node3D
@export var team_score_calculator: TeamScoreCalculator

@export var team_scores = {}

var spawn_points
var team_colors = {
	TeamsLobby.Team.LEFT: Color.TRANSPARENT,
	TeamsLobby.Team.RIGHT: Color.TRANSPARENT,
}

func _ready() -> void:
	self.update_scores()
	if not multiplayer.is_server():
		LobbyService.player_loaded.rpc_id(1)
		return

	randomize()
	self.spawn_points = {
		TeamsLobby.Team.LEFT: self.left_spawn_point_list,
		TeamsLobby.Team.RIGHT: self.right_spawn_point_list,
	}
	LobbyService.all_players_loaded.connect(self._server_init)

	for player_id in LobbyService.players:
		var player_info = LobbyService.players[player_id]
		var team = player_info["team"]
		if team_colors[team] == Color.TRANSPARENT:
			team_colors[team] = player_info["color"]

	print(team_colors)
	self.team_score_calculator.set_player_colors([team_colors[TeamsLobby.Team.LEFT], team_colors[TeamsLobby.Team.RIGHT]])
	self.team_score_calculator.init_texture_map(self.map.mesh_viewport_map)
	self.team_score_calculator.start_calculation()
	LobbyService.player_loaded.rpc_id(1)

func _server_init():
	print("Initting server")
	ProcessProjectileCollisions.connect("palyer_hit", handle_player_hit)

	self.spawn_players()

func _pick_spawn_point(team: TeamsLobby.Team) -> Vector3:
	var points_available = self.spawn_points[team].get_children()
	var chosen = points_available[randi() % points_available.size()] as Node3D
	(self.spawn_points[team] as Node).remove_child(chosen)

	return chosen.position

func spawn_players():
	for player_id in LobbyService.players:
		var player_info = LobbyService.players[player_id]
		var team = player_info["team"]
		
		var initial_pos = self._pick_spawn_point(team)
		
		var player = self.spawner.spawn({
			'peer_id': player_id,
			'player_name': player_info["name"],
			'color': team_colors[team],
			'initial_pos': initial_pos
		})
		
		if player.get_parent() == null and player_id == 1:
			self.players_node.add_child(player)
		
		print(str("Player #", player_id, " spawned."))

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("quit"):
		self.get_tree().quit()

func handle_player_hit(hitter: String, hittee: String) -> void:
	if not multiplayer.is_server():
		return

	var attacker = self.players_node.get_node(str(hitter)) as Player
	var target = self.players_node.get_node(str(hittee)) as Player

	if attacker.color == target.color:
		return

	print(str("At #", multiplayer.get_unique_id(), " #", str(hitter).to_int(), " hitted #", str(hittee).to_int()))
	target.take_damage.rpc_id(str(hittee).to_int(), attacker.get_path())

func update_scores():
	if multiplayer.is_server():
		self.team_scores = self.team_score_calculator.get_score()
		print("SCORE: ", self.team_scores)
	
	var my_player = self.players_node.get_node(str(multiplayer.get_unique_id())) as Player
	if my_player != null:
		my_player.set_score.rpc(self.team_scores[my_player.color])
	await self.get_tree().create_timer(1).timeout
	self.update_scores()
