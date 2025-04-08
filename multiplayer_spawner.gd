extends MultiplayerSpawner

@export var SpawnScene: PackedScene

func _init() -> void:
  spawn_function = _spawn_custom

func _spawn_custom(data: Variant) -> Node:
  var player: Player = SpawnScene.instantiate() as Player
  player.name = str(data.peer_id)

  # Lots of other helpful init things you can do here: e.g.
  player.color = data.color
  player.position = data.initial_pos

  return player
