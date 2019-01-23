extends Control

onready var lapLabel = $Label
onready var track = $"/root/Root/Viewport/Track"

var last_gate = 0
var current_gate = 0
var gate_count = -1

var lap_time = 0
var last_lap_time = 0
var best_lap_time = null

var started = false

func _ready():
	if track == null:
		return

	gate_count = track.gates.size()
	for i in range(gate_count):
		var gate = track.get_child(i)
		gate.get_node("Area").connect("body_entered", self, "gate_entered", [i])
	track.light_gate(current_gate)

func _process(delta):
	if track == null:
		return
	if started:
		lap_time += delta

	var best = str(best_lap_time)
	if best_lap_time == null:
		best = "none"
	lapLabel.text = "best: " + best + " s\n" + \
					"last: " + str(last_lap_time) + " s\n" + \
					"cur:  " + str(lap_time) + " s"

	if Input.is_action_just_pressed("reset"):
		last_gate = current_gate
		current_gate = 0
		lap_time = 0
		started = false
		track.light_gate(current_gate)


func gate_entered(obj, idx):
	if obj != Globals.kwad:
		return
	if idx != current_gate:
		return
	
	
	if current_gate == 0:
		if started:
			last_lap_time = lap_time
			if best_lap_time == null or lap_time < best_lap_time:
				best_lap_time = lap_time
		started = true
		lap_time = 0
	
	last_gate = current_gate
	current_gate = (current_gate + 1) % gate_count
	track.light_gate(current_gate)