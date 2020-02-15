tool
extends Control

class_name StickView

export(bool) var show_aux = false

var axis_provider = Settings

func _ready():
	pass

func _process(_delta):
	update()

func draw_aux(pos, size, val):
	draw_line(Vector2(pos.x, pos.y + size.y / 2),
			  Vector2(pos.x + size.x, pos.y + size.y / 2),
			  Color.black)

	var v = (1.0 + val) / 2
	draw_circle(Vector2(pos.x + v * size.x, pos.y + size.y / 2), 
				5.0, 
				Color.red)

func draw_stick(pos, size, val):
	draw_rect(Rect2(pos.x, pos.y, size.x, size.y), Color(0, 0, 0, 0.3))
	draw_line(Vector2(pos.x, pos.y + size.y/2), 
			  Vector2(pos.x + size.x, pos.y + size.y/2), 
			  Color.black)
	draw_line(Vector2(pos.x + size.x/2, pos.y), 
			  Vector2(pos.x + size.x/2, pos.y + size.y), 
			  Color.black)

	var y = (-val.y + 1.0) / 2.0 * size.y
	var x = (val.x + 1.0)  / 2.0 * size.x
	draw_circle(Vector2(pos.x + x, pos.y + y), 5.0, Color.red)

func _draw():
	var axis1 = Vector2()
	var axis2 = Vector2()
	var aux = [0, 0, 0, 0]
	if not Engine.editor_hint:
		axis1.x = axis_provider.get_axis(3)
		axis1.y = axis_provider.get_axis(2)
		axis2.x = axis_provider.get_axis(0)
		axis2.y = axis_provider.get_axis(1)
		for i in range(4):
			aux[i] = axis_provider.get_axis(4 + i)
	var ctrl_size = get_rect().end - get_rect().position
	
	var min_size = min(ctrl_size.x/2, ctrl_size.y * 0.8)
	var size = Vector2(min_size, min_size)
	var y_offset = ctrl_size.y - size.y
	
	draw_stick(Vector2(0, y_offset), size, axis1)
	draw_stick(Vector2(ctrl_size.x - size.x, y_offset), size, axis2)
	
	if not show_aux:
		return
	
	draw_aux(Vector2(), Vector2(size.x, 0.1 * ctrl_size.y), aux[0])
	draw_aux(Vector2(ctrl_size.x - size.x, 0), Vector2(size.x, 0.1 * ctrl_size.y), aux[1])
	draw_aux(Vector2(0, 0.1 * ctrl_size.y), Vector2(size.x, 0.1 * ctrl_size.y), aux[2])
	draw_aux(Vector2(ctrl_size.x - size.x, 0.1 * ctrl_size.y), Vector2(size.x, 0.1 * ctrl_size.y), aux[3])