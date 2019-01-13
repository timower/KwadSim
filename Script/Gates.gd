extends Spatial

onready var lapLabel = $"/root/Root/LapTimes/Label"

var last_gate = 0
var current_gate = 0
var gate_count = -1

var lap_time = 0
var last_lap_time = 0

var started = false

func _ready():
	gate_count = get_child_count()
	for i in range(gate_count):
		var gate = get_child(i)
		gate.get_node("Area").connect("body_entered", self, "gate_entered", [i])
	light_gate()

func _process(delta):
	if started:
		lap_time += delta

	lapLabel.text = "last: " + str(last_lap_time) + " s\n" + \
					"cur:  " + str(lap_time) + " s"

	if Input.is_action_just_pressed("reset"):
		last_gate = current_gate
		current_gate = 0
		lap_time = 0
		started = false
		light_gate()

func light_gate():
	get_child(last_gate).get_node("Light").visible = false
	get_child(current_gate).get_node("Light").visible = true

func gate_entered(obj, idx):
	if obj != Globals.kwad:
		return
	if idx != current_gate:
		return
	
	
	if current_gate == 0:
		if started:
			last_lap_time = lap_time
		started = true
		lap_time = 0
	
	last_gate = current_gate
	current_gate = (current_gate + 1) % gate_count
	light_gate()