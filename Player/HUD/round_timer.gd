extends Control
class_name RoundTimer

@export var label: Label
@export var timer: Timer
@export var time: float = 180

func _ready() -> void:
	self.label.text = "00:00"

func start() -> void:
	self.timer.start(time)

func _process(_delta) -> void:
	var time_left = self.timer.time_left
	var minutes = int(time_left / 60)
	var seconds = int(time_left) % 60

	self.label.text = "%02d:%02d" % [minutes, seconds]
