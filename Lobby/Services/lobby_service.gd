@tool
extends Node

# These signals can be connected to by a UI lobby scene or the game scene.
signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected
signal player_info_updated(peer_id, new_player_info, prev_player_info)
signal all_players_loaded

const DEFAULT_PORT = 8081
const DEFAULT_SERVER_IP = "127.0.0.1"

var players = {}

var players_loaded = 0

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func join_game(address: String = "", port: int = -1):
	if address.is_empty():
		address = DEFAULT_SERVER_IP
	if port <= 0:
		port = DEFAULT_PORT
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	if error:
		return error
	multiplayer.multiplayer_peer = peer
	
	return OK

func create_game():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(DEFAULT_PORT)
	if error:
		return error
	multiplayer.multiplayer_peer = peer

	players[1] = self.get_player_info(1)
	player_connected.emit(1, players[1])

	return OK

func remove_multiplayer_peer():
	multiplayer.multiplayer_peer = null
	players.clear()

@rpc("call_local", "reliable")
func load_game(game_scene_path: String):
	get_tree().change_scene_to_file(game_scene_path)

@rpc("any_peer", "call_local", "reliable")
func player_loaded():
	if multiplayer.is_server():
		players_loaded += 1
		if players_loaded == players.size():
			print("All players loaded")
			self.all_players_loaded.emit()
			players_loaded = 0

func random_color():
	var colors = [Color(1.0, 0.0, 0.0),
		  Color(0.0, 1.0, 0.0),
		  Color(0.0, 0.0, 1.0)]
	return colors[randi() % colors.size()]

func set_player_info(id: int, new_player_info: Variant):
	self.players[id] = self.players[id]
	
	for player_id in self.players:
		if id == player_id:
			continue
		self._update_player_info.rpc_id(player_id, new_player_info)

func get_player_info(id: int) -> Variant:
	var existing_data = self.players.get(id)
	if existing_data:
		return existing_data

	self.players[id] = {
		"name": str('#', id),
		"color": self.random_color(),
		"team": -1,
		"ready": false,
	}

	return self.players[id]

func _on_player_connected(id):
	var my_id = multiplayer.get_unique_id()
	_register_player_info.rpc_id(id, self.get_player_info(my_id))

@rpc("any_peer", "reliable")
func _register_player_info(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)
	
@rpc("any_peer", "reliable")
func _update_player_info(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	var previous_player_info = players[new_player_id].duplicate()
	players[new_player_id] = new_player_info
	player_info_updated.emit(new_player_id, new_player_info, previous_player_info)

func _on_player_disconnected(id):
	players.erase(id)
	player_disconnected.emit(id)

func _on_connected_to_server():
	var my_id = multiplayer.get_unique_id()
	players[my_id] = self.get_player_info(my_id)
	player_connected.emit(my_id, players[my_id])

func _on_connected_fail():
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()
