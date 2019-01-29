extends Node

var joyConf = null
var kwad = null

var s3d_width = 1280
var s3d_height = 720
var shadows = true

var quads = {}
var selected_quad = "QQ190"
var selected_track = null

const TRACK_PATH = "user://Tracks/"

const OBJECTS = [
	{"name": "Start Box", "scene": preload("res://Models/startbox/startbox.gltf"), "is_gate": false},
	{"name": "Square Gate", "scene": preload("res://Models/SquareGate.tscn"), "is_gate": true},
	{"name": "Full Gate", "scene": preload("res://Models/SquareGateFull.tscn"), "is_gate": true},
	{"name": "Round Gate", "scene": preload("res://Models/GateTest.tscn"), "is_gate": true},
	{"name": "Flag Gate", "scene": preload("res://Models/FlagTest.tscn"), "is_gate": true},
	{"name": "Cone", "scene": preload("res://Models/ConeTest.tscn"), "is_gate": false},
	{"name": "Flag", "scene": preload("res://Models/FlagTest.tscn"), "is_gate": false},
]

const SCENES = [
	{"name": "Default", "scene": preload("res://Nodes/DefaultGround.tscn")},
	{"name": "Garage", "scene": preload("res://Nodes/Garage.tscn")}
]

signal settings_changed

signal reset

func reload_quads():
	var def_quads = read_json("res://Data/quads.json")
	for quad in def_quads:
		quads[quad] = def_quads[quad]

#	var user_quads = read_json("user://quads.json")
#	if user_quads == null:
#		return
#
#	for quad in user_quads:
#		quads[quad] = user_quads[quad]

func _ready():
	reload_quads()
	
	
func reset():
	emit_signal("reset")

func _process(delta):
	if Input.is_action_just_pressed("reset"):
		emit_signal("reset")
		

func update_settings():
	emit_signal("settings_changed")

func read_json(name):
	var file = File.new()
	if not file.file_exists(name):
		return null
	file.open(name, file.READ)
	var conts = parse_json(file.get_as_text())
	file.close()
	return conts

func list_dir(name):
	var dir = Directory.new()
	if dir.open(name) != OK:
		return null
	dir.list_dir_begin(true)
	
	var list = []
	
	var file = dir.get_next()
	while (file != ""):
		list.append(file.get_basename())
		file = dir.get_next()
		
	return list