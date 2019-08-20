extends Node

#warning-ignore-all:unused_class_variable

var joyConf = null
var kwad = null setget ,get_kwad

var s3d_width = 1280
var s3d_height = 720
var shadows = true

var quads = {}
var selected_quad = "QQ190"
var selected_track = null

const TRACK_PATH = "user://Tracks/"
const TRACK_THUMBS_PATH = "user://Tracks/thumb/"
const BUILTIN_TRACKS_PATH = "res://Data/Tracks/"
const THUMBS_PATH = "user://thumbs/"

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

signal rc_input

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
	load_object_thumbs()
	

func load_object_thumbs():
	var file = File.new()
	var dir = Directory.new()
	
	if not dir.dir_exists(THUMBS_PATH):
		dir.make_dir(THUMBS_PATH)
	
	for obj_id in OBJECTS.size():
		var thumb_name = THUMBS_PATH + str(obj_id) + ".png"
		if file.file_exists(thumb_name):
			OBJECTS[obj_id].thumb = ImageTexture.new()
			OBJECTS[obj_id].thumb.load(thumb_name)
		else:
			OBJECTS[obj_id].thumb = null
	
func reset():
	emit_signal("reset")

func _process(_delta):
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

func list_dir(name: String):
	var dir = Directory.new()
	if dir.open(name) != OK:
		return null
	dir.list_dir_begin(true)
	
	var list = []
	
	var file = dir.get_next()
	while (file != ""):
		if not dir.current_is_dir():
			list.append(file.get_basename())
		file = dir.get_next()
		
	return list
	
func get_tracks():
	var builtins = Globals.list_dir(BUILTIN_TRACKS_PATH)
	var tracks = Globals.list_dir(TRACK_PATH)
	var dir = Directory.new()
		
	if tracks == null:
		dir.make_dir(TRACK_PATH)
		tracks = builtins
	else:
		# TODO: duplicates?
		for track in tracks:
			builtins.erase(track)
		tracks += builtins
	
	if not dir.dir_exists(TRACK_THUMBS_PATH):
		dir.make_dir(TRACK_THUMBS_PATH)
		
	var file = File.new()
	for i in range(tracks.size()):
		var thumb = null
		var thumb_path = TRACK_THUMBS_PATH + tracks[i] + ".png"
		if file.file_exists(thumb_path):
			thumb = ImageTexture.new()
			thumb.load(thumb_path)
		tracks[i] = [tracks[i], thumb]
	return tracks

func new_rc_input(inputs):
	emit_signal("rc_input", inputs)

func get_kwad():
	var nodes = get_tree().get_nodes_in_group("Kwad")
	if nodes == null or nodes.size() == 0:
		return null
	return nodes[0]