extends Node2D

@export var texture: Array[Texture2D]
@export var brush_size: int = 100

var queue = []

@rpc
func queue_brush(paint_position: Vector2, color: Color):
	queue.push_back([paint_position, color])
	queue_redraw()

func _draw() -> void:
	for brush in queue:
		draw_texture_rect(texture[0], Rect2(brush[0].x - int(brush_size/2.), brush[0].y - int(brush_size/2.), brush_size, brush_size), false, brush[1])
