extends Control

export(int) var axis1 = 0
export(int) var axis2 = 1

func _ready():
	pass

func _process(_delta):
	update()

func _draw():
	var joyConf = Globals.joyConf
	var size = get_rect().end - get_rect().position
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0, 0, 0, 0.3))
	draw_line(Vector2(0, size.y/2), Vector2(size.x, size.y/2), Color.black)
	draw_line(Vector2(size.x/2, 0), Vector2(size.x/2, size.y), Color.black)
	var y = (-joyConf.axis[axis1].value + 1.0) / 2.0 * size.y
	var x = (joyConf.axis[axis2].value + 1.0)  / 2.0 * size.x
	draw_circle(Vector2(x, y), 5.0, Color.red)