extends Panel

@export var max_value: int = 0
@export var current_value: int = 0
@export var HeartPointScene: PackedScene = preload("res://Player/HUD/HPBar/hp_point.tscn")

@onready var hbox_container = $HBoxContainer

var hp_points = []

func _enter_tree() -> void:
	if not self.is_multiplayer_authority():
		return

	for i in range(max_value):
		var hp_point = HeartPointScene.instantiate()
		self.hp_points.append(hp_point)

func _ready() -> void:
	if not self.is_multiplayer_authority():
		return

	var heart_size = self.hp_points[0].size
	self.size = Vector2((heart_size[0] + 5) * len(self.hp_points), heart_size[1])

	for idx in range(max_value):
		if idx < current_value :
			self.hp_points[idx].increase()
		else:
			self.hp_points[idx].decrease()
		self.hbox_container.add_child(self.hp_points[idx])


func set_value(value: int) -> void:
	self.current_value = value
	for idx in range(max_value):
		if idx < current_value:
			self.hp_points[idx].increase()
		else:
			self.hp_points[idx].decrease()
	
