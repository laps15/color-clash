extends SubViewport

@onready var brush: Node2D = $Brush

func paint(pos: Vector2, color: Color = Color(255,0,0)):
	print(str("At #", multiplayer.get_unique_id(), " painting at (", pos[0], ", ", pos[1], ")"))
	brush.queue_brush(pos, color)
