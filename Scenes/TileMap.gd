extends TileMap

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

const WIDTH = 30
const HEIGHT = 16

# Called when the node enters the scene tree for the first time.
func _ready():
	clear()
	var sx = get_viewport_rect().size.x
	var sy = get_viewport_rect().size.y
	
	var nx = sx / cell_size.x
	var ny = sy / cell_size.y
	var scale_x = nx / WIDTH
	var scale_y = ny / HEIGHT
	
	if scale_x < scale_y:
		scale = Vector2(scale_x, scale_x)
		var h = HEIGHT * cell_size.y * scale_x
		position.y = (sy - h) / 2
	else:
		scale = Vector2(scale_y, scale_y)
		var w = WIDTH * cell_size.x * scale_y
		position.x = (sx - w) / 2

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass