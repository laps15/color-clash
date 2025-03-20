extends CanvasLayer

@onready var game_over_overlay = $GameOver
@onready var kd_pannel = $KDPanel/Label
@onready var hp_bar = $HPBar
@onready var player_name_label = $PlayerIdContainer/Label

var player_ref: Player = null
var kills: int = 0
var deaths: int = 0

func _ready():
	if not self.is_multiplayer_authority():
		return

	self.update_kd_display()
	self.set_player_name()

func display_game_over(player: Player) -> void:
	if not self.is_multiplayer_authority():
		return

	player_ref = player
	game_over_overlay.show()

func update_kd_display() -> void:
	if not self.is_multiplayer_authority():
		return
		
	kd_pannel.text = str(self.kills, " / ", self.deaths)

@rpc("call_local")
func update_hp(hp_value: int) -> void:
	if not self.is_multiplayer_authority():
		return

	hp_bar.set_value(hp_value)

func set_player_name() -> void:
	if not self.is_multiplayer_authority():
		return

	player_name_label.text = str('#', self.get_multiplayer_authority())

func increase_kill_count() -> void:
	if not self.is_multiplayer_authority():
		return

	self.kills += 1
	self.update_kd_display()

func increase_death_count() -> void:
	if not self.is_multiplayer_authority():
		return

	self.deaths += 1
	self.update_kd_display()

func _on_respawn_button_pressed() -> void:
	game_over_overlay.hide()
	player_ref.respawn()
	player_ref = null
