extends Node

@export_file("*.tscn","*.scn") var game_scene_path: String
@export var landing_page: LandingPage
@export var lobby_page: CanvasLayer

func _ready() -> void:
	self.lobby_page.hide()
	self.landing_page.done.connect(self._switch_to_lobby)
	self.lobby_page.start_game.connect(self._start_game)

func _switch_to_lobby() -> void:
	self.landing_page.hide()
	self.lobby_page.show()

func _start_game() -> void:
	if self.game_scene_path:
		LobbyService.load_game.rpc(self.game_scene_path)
