extends Control

onready var joyConf = $"/root/Root/JoyConf"

export(int) var axis1 = 0
export(int) var axis2 = 1

func _ready():
	pass

func _process(delta):
	update()

var touch_pointer = -1

func _gui_input(event):
	if event is InputEventScreenDrag:
		var size = get_rect().end - get_rect().position
		var pos = event.position
		joyConf.axis[axis1].value = -clamp(2 * (pos.y / size.y) - 1, -1, 1)
		joyConf.axis[axis1].has_moved = true
		joyConf.axis[axis2].value = clamp(2 * (pos.x / size.x) - 1, -1, 1)
		joyConf.axis[axis2].has_moved = true
		#$"/root/Root/Sticks/Label".text = str(event.position)

func _draw():
	var size = get_rect().end - get_rect().position
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0, 0, 0, 0.3))
	draw_line(Vector2(0, size.y/2), Vector2(size.x, size.y/2), Color.black)
	draw_line(Vector2(size.x/2, 0), Vector2(size.x/2, size.y), Color.black)
	
	var y = (-joyConf.axis[axis1].value + 1) / 2 * size.y
	var x = (joyConf.axis[axis2].value + 1)  /2 * size.x
	
	draw_circle(Vector2(x, y), 5.0, Color.red)