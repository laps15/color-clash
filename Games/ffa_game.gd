extends Node

@export var current_level: PackedScene

@onready var spawner = $MultiplayerSpawner

func _ready() -> void:
	LobbyService.player_loaded.rpc_id(1)
	if not self.is_multiplayer_authority():
		return

	LobbyService.all_players_loaded.connect(self._server_init)

func _server_init():
	print("Initting server")
	ProcessProjectileCollisions.connect("palyer_hit", handle_player_hit)

	self.spawn_players()

func spawn_players():
	for player_id in LobbyService.players:
		var initial_pos = Vector3(-30 + randf_range(-10,10), 0, -30 + randf_range(-10, 10))
		var color = LobbyService.players[player_id]["color"]
		
		var player = self.spawner.spawn({
			'peer_id': player_id,
			'player_name': LobbyService.players[player_id]["name"],
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
	
	print(str("At #", multiplayer.get_unique_id(), " #", str(hitter).to_int(), " hitted #", str(hittee).to_int()))
	target.take_damage.rpc_id(str(hittee).to_int(), attacker.get_path())
