extends Node

@export var current_level: PackedScene

@onready var main_menu = $CanvasLayer/MainMenu
@onready var adress_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry

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
	
	enet_peer.create_client(adress_entry.text, PORT)
	multiplayer.multiplayer_peer = enet_peer

func add_player(peer_id):
	var player = PlayerScene.instantiate()
	player.name = str(peer_id)
	player.set_color(player_colors.pop_front())
	self.add_child(player)
	player.global_position = Vector3(randf_range(-10,10), 0, randf_range(-10, 10))
	print(str("Player #", peer_id, " spawned."))
	
func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

func upnp_setup():
	var upnp = UPNP.new()
	var discover_result = upnp.discover()
	
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP discover failed! Reason: %s" % discover_result)
		
	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), \
		"UPNP Invalid Gateway!")
		
	var map_result = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP port mapping failed! Error %s" % map_result)
		
	print("Success! Join Address: %s" % upnp.query_external_address())
