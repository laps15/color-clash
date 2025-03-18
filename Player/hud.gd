extends CanvasLayer

@onready var game_over_overlay = $GameOver

var player_ref: Player = null

func display_game_over(player: Player) -> void:
	player_ref = player
	player_ref.die()
	game_over_overlay.show()

func _on_respawn_button_pressed() -> void:
	game_over_overlay.hide()
	player_ref.respawn()
	player_ref = null
