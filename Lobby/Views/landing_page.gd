extends CanvasLayer
class_name LandingPage

signal done

@export var address_input: LineEdit

func _on_host_button_pressed() -> void:
	var error = LobbyService.create_game()
	assert(error == OK, str("Error creating server, error code: ", error))
	done.emit()

func _on_join_button_pressed() -> void:
	var result = self.get_parsed_address()
	var error = LobbyService.join_game(result[0], result[1])
	assert(error == OK, str("Error joining game, error code: ", error))
	done.emit()

func get_parsed_address() -> Array:
	var addr: String = ""
	var port: int = -1
	
	var addr_from_input = self.address_input.text
	print(addr_from_input)
	
	var port_extraction_regex = RegEx.new()
	port_extraction_regex.compile(r"^(.+)(:\d{4,5})$")
	var regex_result = port_extraction_regex.search(addr_from_input)
	if regex_result:
		addr = regex_result.get_string(1)
		var port_str = regex_result.get_string(2)
		port = int(port_str.lstrip(":"))
	else:
		addr = addr_from_input
		
	return [addr,port]
