extends PanelContainer
class_name PlayerCard

const my_scene = preload("./player_card.tscn")

@export var player_color_picker: ColorPickerButton
@export var player_name_label: Label
@export var start_edit_button: Button
@export var player_name_input: LineEdit
@export var save_name_button: Button

@export var player_name: String
@export var player_color: Color

static func new_player_card(_player_name: String, _player_color: Color) -> PlayerCard:
	var new_card = my_scene.instantiate()
	new_card.set_player_name(_player_name)\
		.set_player_color(_player_color)
	return new_card

func _enter_tree() -> void:
	self.set_multiplayer_authority(int(self.name), true)

func _ready() -> void:
	self.player_name_label.text = self.player_name
	self.player_color_picker.color = self.player_color
	
	self.player_name_input.hide()
	self.save_name_button.hide()
	
	if not self.is_multiplayer_authority():
		self.start_edit_button.hide()
		self.player_color_picker.disabled = true
	else:
		self.start_edit_button.show()
		self.save_name_button.pressed.connect(self._on_save_name_pressed)
		self.player_color_picker.popup_closed.connect(self._on_color_picker_button_popup_closed)

func set_player_name(new_player_name: String) -> PlayerCard:
	self.player_name = new_player_name
	self.player_name_label.text = new_player_name
	self.player_name_input.text = new_player_name
	return self

func get_player_name() -> String:
	return self.self.player_name

func set_player_color(new_player_color: Color) -> PlayerCard:
	self.player_color = new_player_color
	self.player_color_picker.color = new_player_color
	return self
	
func get_player_color() -> Color:
	return self.player_color_picker.color

func _toggle_edit() -> void:
	if self.player_name_input.visible:
		self.player_name_input.hide()
		self.save_name_button.hide()
		
		self.player_name_label.show()
		self.start_edit_button.show()
		return

	self.player_name_input.show()
	self.save_name_button.show()
	
	self.player_name_label.hide()
	self.start_edit_button.hide()

func _on_player_name_change(new_name: String, player_id: int) -> void:
	var player_info = LobbyService.get_player_info(player_id)

	player_info["name"] = new_name
	LobbyService.set_player_info(player_id, player_info)

func _on_save_name_pressed() -> void:
	var player_id = multiplayer.get_unique_id()
	var clean_name = self.player_name_input.text.lstrip(' ').rstrip(' ')
	if clean_name.is_empty():
		return

	self.set_player_name(clean_name)
	self.player_name_input.hide()
	self.save_name_button.hide()
	
	self.player_name_label.show()
	self.start_edit_button.show()
	
	var player_info = LobbyService.get_player_info(player_id)

	player_info["name"] = clean_name
	LobbyService.set_player_info(player_id, player_info)

func _on_color_picker_button_popup_closed() -> void:
	var player_id = multiplayer.get_unique_id()
	var player_info = LobbyService.get_player_info(player_id)

	player_info["color"] = self.player_color_picker.color
	LobbyService.set_player_info(player_id, player_info)
