@tool
extends CanvasLayer
class_name TeamsLobby

signal start_game()

@export var PlayerCardScene: PackedScene

@export var left_team_player_list: VBoxContainer
@export var left_team_join_button: Button

@export var right_team_player_list: VBoxContainer
@export var right_team_join_button: Button

@export var queue_player_list: VBoxContainer
@export var queue_join_button: Button
@export var start_game_button: Button
@export var switch_game_mode_button: Button

@export var confirm_start_dialog: AcceptDialog

enum Team {
	NONE = -1,
	LEFT,
	RIGHT,
}

var player_cards = {}
var players_unready = 0

func _ready() -> void:
	LobbyService.player_connected.connect(self._on_player_connected)
	LobbyService.player_disconnected.connect(self._on_player_disconnected)
	LobbyService.player_info_updated.connect(self._on_player_info_updated)

func update_ui_elements_by_team(team: Team) -> void:
	self.queue_join_button.show()
	self.left_team_join_button.show()
	self.right_team_join_button.show()
	
	if not self.is_multiplayer_authority():
		self.start_game_button.hide()
		self.switch_game_mode_button.hide()
	else:
		self.start_game_button.show()
		self.switch_game_mode_button.show()

	match team:
		Team.NONE:
			self.queue_join_button.hide()
		Team.LEFT:
			self.left_team_join_button.hide()
		Team.RIGHT:
			self.right_team_join_button.hide()

func _on_player_connected(peer_id: int, player_info: Variant) -> void:
	var card = PlayerCard.new_player_card(player_info["name"], player_info["color"])

	if peer_id == multiplayer.get_unique_id():
		card.name = str(peer_id)
		self.update_ui_elements_by_team(player_info["team"])

	self._add_card(player_info["team"], card)

	self.player_cards[peer_id] = card

func _on_player_disconnected(player_id: int) -> void:
	var card = self.player_cards[player_id]
	var player_info = LobbyService.get_player_info(player_id)
	self._remove_card(player_info["team"], card)

func _on_player_info_updated(player_id: int, new_player_info, prev_player_info) -> void:
	var card = self.player_cards[player_id] as PlayerCard

	card.set_player_name(new_player_info["name"])\
		.set_player_color(new_player_info["color"])

	self._remove_card(prev_player_info["team"], card)
	self._add_card(new_player_info["team"], card)

func _add_card(team: Team, card: PlayerCard) -> void:
	match team:
		Team.NONE:
			self.players_unready += 1
			self.queue_player_list.add_child(card)
		Team.LEFT:
			self.left_team_player_list.add_child(card)
		Team.RIGHT:
			self.right_team_player_list.add_child(card)

func _remove_card(team: Team, card: PlayerCard) -> PlayerCard:
	match team:
		Team.NONE:
			self.players_unready -= 1
			self.queue_player_list.remove_child(card)
		Team.LEFT:
			self.left_team_player_list.remove_child(card)
		Team.RIGHT:
			self.right_team_player_list.remove_child(card)

	return card

func _move_card(player_id: int, to_team: Team) -> void:
	var card = self.player_cards[player_id]
	var player_info = LobbyService.get_player_info(player_id)

	self._remove_card(player_info["team"], card)
	self._add_card(to_team, card)

	player_info["team"] = to_team
	LobbyService.set_player_info(player_id, player_info)
	self.update_ui_elements_by_team(to_team)

func _on_join_queue_button_pressed() -> void:
	self._move_card(multiplayer.get_unique_id(), Team.NONE)

func _on_join_left_button_pressed() -> void:
	self._move_card(multiplayer.get_unique_id(), Team.LEFT)
	
func _on_join_right_button_pressed() -> void:
	self._move_card(multiplayer.get_unique_id(), Team.RIGHT)

func _on_start_game_button_pressed() -> void:
	if players_unready > 0:
		self.confirm_start_dialog.show()
		return

	self.hide()
	self.start_game.emit()
