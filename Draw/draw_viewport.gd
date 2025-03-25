extends SubViewport

@onready var brush: Node2D = $Brush

func paint(pos: Vector2, color: Color = Color(255,0,0)):
	brush.queue_brush(pos, color)
