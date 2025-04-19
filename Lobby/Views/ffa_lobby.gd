@tool
extends CanvasLayer

signal start_game

@export var PlayerCardScene: PackedScene

@export var left_player_list: VBoxContainer
@export var right_player_list: VBoxContainer
@export var queue_player_list: VBoxContainer

@export var ready_button: Button
@export var unready_button: Button
@export var start_game_button: Button
@export var switch_game_mode_button: Button

@export var confirm_start_dialog: AcceptDialog

enum PlayerList {
	QUEUE = -1,
	LEFT,
	RIGHT,
}

const MAX_PLAYERS_PER_LIST = 11

var player_cards = {}
var player_on_ui_list = {}
var players_on_list = {
	PlayerList.QUEUE: 0,
	PlayerList.LEFT: 0,
	PlayerList.RIGHT: 0,
}

func _ready() -> void:
	LobbyService.player_connected.connect(self._on_player_connected)
	LobbyService.player_disconnected.connect(self._on_player_disconnected)
	LobbyService.player_info_updated.connect(self._on_player_info_updated)


func update_ui_elements_by_list(on_list: PlayerList) -> void:
	self.ready_button.show()
	self.unready_button.show()

	if not self.is_multiplayer_authority():
		self.start_game_button.hide()
		self.switch_game_mode_button.hide()
	else:
		self.start_game_button.show()
		self.switch_game_mode_button.show()

	match on_list:
		PlayerList.QUEUE:
			self.ready_button.show()
			self.unready_button.hide()

		PlayerList.LEFT, PlayerList.RIGHT:
			self.ready_button.hide()
			self.unready_button.show()


func _on_player_connected(peer_id: int, player_info: Variant) -> void:
	var card = PlayerCard.new_player_card(player_info["name"], player_info["color"])

	self.player_on_ui_list[peer_id] = self._get_list_to_add(player_info["ready"])

	if peer_id == multiplayer.get_unique_id():
		card.name = str(peer_id)
		self.update_ui_elements_by_list(self.player_on_ui_list[peer_id])

	self._add_card(self.player_on_ui_list[peer_id], card)

	self.player_cards[peer_id] = card

func _on_player_disconnected(player_id: int) -> void:
	var card = self.player_cards[player_id]
	var player_info = LobbyService.get_player_info(player_id)
	self._remove_card(player_info["team"], card)

func _on_player_info_updated(player_id: int, new_player_info, _prev_player_info) -> void:
	var card = self.player_cards[player_id] as PlayerCard
	var on_list = self.player_on_ui_list[player_id]
	var to_list = self._get_list_to_add(new_player_info["ready"])
	
	card.set_player_name(new_player_info["name"])\
		.set_player_color(new_player_info["color"])

	self._remove_card(on_list, card)
	self._add_card(to_list, card)
	self.player_on_ui_list[player_id] = to_list

func _add_card(on_list: PlayerList, card: PlayerCard) -> void:
	match on_list:
		PlayerList.QUEUE:
			self.players_on_list[PlayerList.QUEUE] += 1
			self.queue_player_list.add_child(card)
		PlayerList.LEFT:
			self.players_on_list[PlayerList.LEFT] += 1
			self.left_player_list.add_child(card)
		PlayerList.RIGHT:
			self.players_on_list[PlayerList.RIGHT] += 1
			self.right_player_list.add_child(card)

func _remove_card(on_list: PlayerList, card: PlayerCard) -> PlayerCard:
	match on_list:
		PlayerList.QUEUE:
			self.players_on_list[PlayerList.QUEUE] -= 1
			self.queue_player_list.remove_child(card)
		PlayerList.LEFT:
			self.players_on_list[PlayerList.LEFT] -= 1
			self.left_player_list.remove_child(card)
		PlayerList.RIGHT:
			self.players_on_list[PlayerList.RIGHT] -= 1
			self.right_player_list.remove_child(card)

	return card

func _move_card(player_id: int, to_list: PlayerList) -> void:
	var card = self.player_cards[player_id]
	var player_info = LobbyService.get_player_info(player_id)

	self._remove_card(player_on_ui_list[player_id], card)
	self._add_card(to_list, card)

	player_on_ui_list[player_id] = to_list
	player_info["ready"] = to_list != PlayerList.QUEUE

	LobbyService.set_player_info(player_id, player_info)
	self.update_ui_elements_by_list(to_list)

func _get_list_to_add(is_ready: bool) -> PlayerList:
	if is_ready:
		return self._get_ready_list_to_add()
	return PlayerList.QUEUE

func _get_ready_list_to_add() -> PlayerList:
	if self.players_on_list[PlayerList.LEFT] >= self.MAX_PLAYERS_PER_LIST:
		return PlayerList.RIGHT

	return PlayerList.LEFT

func _on_unready_button_pressed() -> void:
	self._move_card(multiplayer.get_unique_id(), PlayerList.QUEUE)

func _on_ready_button_pressed() -> void:
	var to_list = self._get_ready_list_to_add()
	self._move_card(multiplayer.get_unique_id(), to_list)

func _on_start_game_button_pressed() -> void:
	if self.players_on_list[PlayerList.QUEUE] > 0:
		self.confirm_start_dialog.show()
		return

	self.hide()
	self.start_game.emit()
