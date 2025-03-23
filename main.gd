extends Node

@export var current_level: PackedScene

@onready var main_menu = $CanvasLayer/MainMenu
@onready var adress_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry
@onready var spawner = $MultiplayerSpawner

var level
var player_colors = [
	Color.RED,
	Color.REBECCA_PURPLE,
	Color.BLUE,
	Color.CORAL,
]

const PlayerScene = preload("res://Player/player.tscn")

const PORT = 8081
var enet_peer = ENetMultiplayerPeer.new()

func _ready() -> void:
	if not self.is_multiplayer_authority():
		return

	ProcessProjectileCollisions.connect("palyer_hit", handle_player_hit)

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("quit"):
		self.get_tree().quit()

func _on_host_button_pressed() -> void:
	#upnp_setup()
	main_menu.hide()
	
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	
	add_player(multiplayer.get_unique_id())

func _on_join_button_pressed() -> void:
	main_menu.hide()
	var addr = adress_entry.text
	var port = PORT
	
	var tks = addr.split(":")
	if len(tks) == 2:
		addr = tks[0]
		port = tks[1]
	
	print(str("Connecting to ", addr, ":", port))
	
	enet_peer.create_client(addr, PORT)
	multiplayer.multiplayer_peer = enet_peer

func add_player(peer_id):
	var initial_pos = Vector3(randf_range(-10,10), 0, randf_range(-10, 10))
	var color = player_colors.pop_front()
	
	var player = self.spawner.spawn({
		'peer_id': peer_id,
		'color': color,
		'initial_pos': initial_pos
	})
	
	self.add_child(player)
	print(str("Player #", peer_id, " spawned."))
	
func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

func upnp_setup():
	var upnp = UPNP.new()
	var discover_result = upnp.discover()
	var device = upnp.get_device(0).get_class()
	var map_result = device.add_port_mapping(PORT)
	
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP discover failed! Reason: %s" % discover_result)
		
	var gtw = upnp.get_gateway().is_valid_gateway()
	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), \
		"UPNP Invalid Gateway!")
		
	map_result = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP port mapping failed! Error %s" % map_result)
		
	print("Success! Join Address: %s" % upnp.query_external_address())

func handle_player_hit(hitter: String, hittee: String) -> void:
	if not self.is_multiplayer_authority():
		return

	var attacker = self.get_node(str(hitter)) as Player
	var target = self.get_node(str(hittee)) as Player
	
	print(str("At #", multiplayer.get_unique_id(), " #", str(hitter).to_int(), " hitted #", str(hittee).to_int()))
	target.take_damage.rpc(target.get_path(), attacker.get_path())
	
	
