extends Panel

@export var respawn_delay: float = 3.0

@onready var timer: Timer = $Timer
@onready var respawn_button: Button = $VBoxContainer/RespawnButton
@onready var countdown: Label = $VBoxContainer/Countdown

func _ready() -> void:
	if not self.is_multiplayer_authority():
		return

func reveal() -> void:
	self.respawn_button.hide()
	self.show()
	self.timer.start(respawn_delay)
	self.countdown.show()

func _process(_delta: float) -> void:
	if not self.is_multiplayer_authority():
		return

	self.countdown.text = "%.2fs" % self.timer.time_left

func _on_timer_timeout() -> void:
	self.countdown.hide()
	self.respawn_button.show()
