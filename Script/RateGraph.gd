extends Control

onready var config = get_parent()

const npoints = 50
const dx = 2.0 / (npoints - 1)

const colors = [Color.green, Color.blue, Color.red]

var points = PoolVector2Array()

func _ready():
	points.resize(npoints)

var maxY = 666

func draw_axis(size, axis):
	for i in range(npoints):
		var x = -1 + dx * i
		var y = config.apply_rates(axis, x)
		points[i].x = (x + 1) / 2 * size.x
		points[i].y = (-y / maxY + 1) / 2  * size.y

	draw_polyline(points, colors[axis])

func _draw():
	if config == null:
		return

	var size = get_rect().end - get_rect().position
	draw_rect(Rect2(Vector2(), size), Color.white)
	draw_line(Vector2(0, size.y/2), Vector2(size.x, size.y/2), Color.black)
	draw_line(Vector2(size.x/2, 0), Vector2(size.x/2, size.y), Color.black)
	
	
	maxY = max(config.apply_rates(0, 1), \
		   max(config.apply_rates(1, 1), \
			   config.apply_rates(2, 1)))
	
	for i in range(3):
		draw_axis(size, i)