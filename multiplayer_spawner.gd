extends MultiplayerSpawner

@export var SpawnScene: PackedScene

func _init() -> void:
	spawn_function = _spawn_custom

func _spawn_custom(data: Variant) -> Node:
	var player: Player = SpawnScene.instantiate() as Player
	player.name = str(data.peer_id)
	player.player_name = data["player_name"]
	player.position = data["initial_pos"]

	# Lots of other helpful init things you can do here: e.g.
	player.color = data.color

	return player
