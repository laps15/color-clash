extends Node

@export var current_level: PackedScene

@onready var main_menu = $CanvasLayer/MainMenu
@onready var adress_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry
@onready var spawner = $MultiplayerSpawner

var level
var player_colors = [
	Color.AZURE,
	Color.SADDLE_BROWN,
	Color.RED,
	Color.REBECCA_PURPLE,
	Color.BLUE,
	Color.CORAL,
	Color.AQUAMARINE,
	Color.CHARTREUSE,
	Color.DARK_MAGENTA,
]

const PlayerScene = preload("res://Player/player.tscn")

const PORT = 8081
var enet_peer = ENetMultiplayerPeer.new()

func _ready() -> void:
	if not self.is_multiplayer_authority():
		return

	ProcessProjectileCollisions.connect("palyer_hit", handle_player_hit)

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("quit"):
		self.get_tree().quit()

func _on_host_button_pressed() -> void:
	#upnp_setup()
	main_menu.hide()
	
	enet_peer.create_server(PORT)
	
	var addr = adress_entry.text.lstrip(' ').rstrip(' ')
	if addr and addr != '':
		print("Binding host address to: ", addr)
		enet_peer.set_bind_ip(addr)
	
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	
	add_player(multiplayer.get_unique_id())
	while true:
		print("Incomming connections: ", enet_peer.get_incoming_connections())
		await self.get_tree().create_timer(1).timeout

func _on_join_button_pressed() -> void:
	main_menu.hide()
	var addr = adress_entry.text.lstrip(' ').rstrip(' ')
	var port = PORT
	
	var tks = addr.split(":")
	if len(tks) == 2:
		addr = tks[0]
		port = tks[1]
	
	
	var error = enet_peer.create_client(addr, PORT)
	if error != OK:
		printerr(error)
	
	multiplayer.multiplayer_peer = enet_peer
	
	print("Peer created status: ", ["Disconected", "Connecting...", "Connected"][enet_peer.get_connection_status()])
	while enet_peer.get_connection_status() == enet_peer.CONNECTION_CONNECTING:
		print("connecting state: ", enet_peer.get_peer(enet_peer.get_packet_peer()).get_state())
		await self.get_tree().create_timer(1).timeout
	
	if enet_peer.get_connection_status() == enet_peer.CONNECTION_CONNECTED:
		print("Connected to: ", enet_peer.host)

func add_player(peer_id):
	print(str("Connection #", peer_id, " received."))
	var initial_pos = Vector3(-30 + randf_range(-10,10), 0, -30 + randf_range(-10, 10))
	var color = player_colors.pop_front()
	
	var player = self.spawner.spawn({
		'peer_id': peer_id,
		'color': color,
		'initial_pos': initial_pos
	})
	
	if not player.get_parent():
		self.add_child(player)
	player.global_position = initial_pos

	print(str("Player #", peer_id, " spawned."))
	
func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

func handle_player_hit(hitter: String, hittee: String) -> void:
	if not self.is_multiplayer_authority():
		return

	var attacker = self.get_node(str(hitter)) as Player
	var target = self.get_node(str(hittee)) as Player
	
	print(str("At #", multiplayer.get_unique_id(), " #", str(hitter).to_int(), " hitted #", str(hittee).to_int()))
	target.take_damage.rpc(target.get_path(), attacker.get_path())
