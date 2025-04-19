extends Node

@export_file("*.tscn","*.scn") var ffa_game_scene_path: String
@export_file("*.tscn","*.scn") var teams_game_scene_path: String
@export var landing_page: LandingPage
@export var ffa_lobby_page: CanvasLayer
@export var teams_lobby_page: CanvasLayer

var game_scene_path: String

func _ready() -> void:
	self.landing_page.show()
	self.ffa_lobby_page.hide()
	self.teams_lobby_page.hide()

	self.landing_page.done.connect(self._switch_to_lobby)
	self.ffa_lobby_page.start_game.connect(self._start_game)
	self.teams_lobby_page.start_game.connect(self._start_game)
	self.game_scene_path = self.teams_game_scene_path
	
	self.ffa_lobby_page.switch_game_mode_button.pressed.connect(self._on_switch_to_teams_pressed.rpc)
	self.teams_lobby_page.switch_game_mode_button.pressed.connect(self._on_switch_to_ffa_pressed.rpc)

func _switch_to_lobby() -> void:
	self.landing_page.hide()
	self.teams_lobby_page.show()

func _start_game() -> void:
	print("Calling start game: ", self.game_scene_path)
	if self.game_scene_path:
		LobbyService.load_game.rpc(self.game_scene_path)

@rpc("call_local")
func _on_switch_to_teams_pressed() -> void:
	self.ffa_lobby_page.hide()
	self.teams_lobby_page.show()
	self.game_scene_path = self.teams_game_scene_path

@rpc("call_local")
func _on_switch_to_ffa_pressed() -> void:
	self.teams_lobby_page.hide()
	self.ffa_lobby_page.show()
	self.game_scene_path = self.ffa_game_scene_path
