extends Node

@export var current_level: PackedScene
@export var left_spawn_point_list: Node
@export var right_spawn_point_list: Node

@onready var spawner = $MultiplayerSpawner

var spawn_points

func _ready() -> void:
	if not multiplayer.is_server():
		LobbyService.player_loaded.rpc_id(1)
		return

	randomize()
	self.spawn_points = {
		TeamsLobby.Team.LEFT: self.left_spawn_point_list,
		TeamsLobby.Team.RIGHT: self.right_spawn_point_list,
	}
	LobbyService.all_players_loaded.connect(self._server_init)
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
	var team_color = {
		TeamsLobby.Team.LEFT: null,
		TeamsLobby.Team.RIGHT: null,
	}
	
	for player_id in LobbyService.players:
		var player_info = LobbyService.players[player_id]
		var team = player_info["team"]
		if team_color[team] == null:
			team_color[team] = player_info["color"]
		var color = team_color[team]
		
		var initial_pos = self._pick_spawn_point(team)
		
		var player = self.spawner.spawn({
			'peer_id': player_id,
			'player_name': player_info["name"],
			'color': color,
			'initial_pos': initial_pos
		})
		
		if player.get_parent() == null and player_id == 1:
			self.add_child(player)
		
		print(str("Player #", player_id, " spawned."))

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("quit"):
		self.get_tree().quit()

func handle_player_hit(hitter: String, hittee: String) -> void:
	if not multiplayer.is_server():
		return

	var attacker = self.get_node(str(hitter)) as Player
	var target = self.get_node(str(hittee)) as Player

	if attacker.color == target.color:
		return

	print(str("At #", multiplayer.get_unique_id(), " #", str(hitter).to_int(), " hitted #", str(hittee).to_int()))
	target.take_damage.rpc_id(str(hittee).to_int(), attacker.get_path())
