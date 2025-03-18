extends Node2D

@export var texture: Texture2D
@export var brush_size: int = 100

var queue = []

@rpc
func queue_brush(position: Vector2, colour: Color):
	queue.push_back([position, colour])
	queue_redraw()

func _draw() -> void:
	for brush in queue:
		draw_texture_rect(texture, Rect2(brush[0].x - brush_size/2, brush[0].y - brush_size/2, brush_size, brush_size), false, brush[1])
