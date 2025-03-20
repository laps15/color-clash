extends CanvasLayer

@onready var game_over_overlay = $GameOver
@onready var kd_pannel = $KDPanel/Label
@onready var hp_bar = $"Health bar"
@onready var player_name_label = $"Player id container/Label"

var peer_id: int
var player_ref: Player = null
var kills: int = 0
var deaths: int = 0

func _ready():
	update_kd_display()

func display_game_over(player: Player) -> void:
	if not self.is_multiplayer_authority():
		return
		
	player_ref = player
	player_ref.die()
	game_over_overlay.show()

func update_kd_display() -> void:
	print(str(self.get_multiplayer_authority(), "Updating KD text"))
	kd_pannel.text = str(self.kills, " / ", self.deaths)

func update_hp(hp_value: int, player: Player) -> void:
	print(str(multiplayer.get_unique_id(), " previous hp_value: ", hp_bar.value))
	print(str(multiplayer.get_unique_id(), " updating hp_value of #", player.name, " to ", hp_value))
	hp_bar.value = hp_value
	print(str(multiplayer.get_unique_id(), " newd hp_value: ", hp_bar.value))

func set_player_name(name: String) -> void:
	player_name_label.text = str('#', name)

func increase_kill_count() -> void:
	if str(multiplayer.get_unique_id()) != str(self.peer_id):
		return
	print(str("At #", self.get_multiplayer_authority(), "increase_kill_count"))
	self.kills += 1
	self.update_kd_display()

func increase_death_count() -> void:
	if str(multiplayer.get_unique_id()) != str(self.peer_id):
		return

	print(str("At #", self.get_multiplayer_authority(), "increase_death_count"))
	self.deaths += 1
	self.update_kd_display()

func _on_respawn_button_pressed() -> void:
	game_over_overlay.hide()
	player_ref.respawn()
	player_ref = null
