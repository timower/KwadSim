extends Node

#warning-ignore-all:unused_class_variable

var kwad = null setget ,get_kwad

var quads = {}
var selected_quad = "QQ190"
var selected_track = null

const TRACK_PATH = "user://Tracks/"
const TRACK_THUMBS_PATH = "user://Tracks/thumb/"
const BUILTIN_TRACKS_PATH = "res://Data/Tracks/"
const THUMBS_PATH = "user://thumbs/"

const BUILTIN_QUADS_PATH = "res://Data/quads.json"

const OBJECTS = [
	{"name": "Start Box", "scene": preload("res://Models/startbox/startbox.gltf"), "is_gate": false},
	# Gates:
	{"name": "Square Gate", "scene": preload("res://Nodes/Gates/SquareGate.tscn"), "is_gate": true},
	{"name": "Full Gate", "scene": preload("res://Nodes/Gates/SquareGateFull.tscn"), "is_gate": true},
	{"name": "Round Gate", "scene": preload("res://Nodes/Gates/GateTest.tscn"), "is_gate": true},
	{"name": "Flag Gate", "scene": preload("res://Nodes/Gates/FlagTest.tscn"), "is_gate": true},
	# Objects:
	{"name": "Cone", "scene": preload("res://Models/discCone/discCone.gltf"), "is_gate": false},
	{"name": "Flag", "scene": preload("res://Nodes/Gates/FlagTest.tscn"), "is_gate": false},
]

const SCENES = [
	{"name": "Default", "scene": preload("res://Nodes/Track/DefaultGround.tscn")},
	{"name": "Garage", "scene": preload("res://Nodes/Track/Garage.tscn")}
]

signal reset


func reload_quads():
	Log.d("Reloading quadcopter definitions from: {}",
		  ProjectSettings.globalize_path(BUILTIN_QUADS_PATH))
	var def_quads = read_json(BUILTIN_QUADS_PATH)
	for quad in def_quads:
		Log.d(" - Got default quad: {}", quad)
		quads[quad] = def_quads[quad]
	Log.d("TODO: User defined quads")
#	var user_quads = read_json("user://quads.json")
#	if user_quads == null:
#		return
#
#	for quad in user_quads:
#		quads[quad] = user_quads[quad]

func _ready():
	Log.d("Initializing Globals")
	reload_quads()
	load_object_thumbs()

func create_image_texture(path):
	var image = Image.new()
	image.load(path)
	var texture = ImageTexture.new()
	texture.create_from_image(image)
	return texture

func load_object_thumbs():
	Log.d("Reading generated thumbnails for objects")
	var file = File.new()
	var dir = Directory.new()

	if not dir.dir_exists(THUMBS_PATH):
		Log.d("No previous thumb directory, creating")
		dir.make_dir(THUMBS_PATH)

	for obj_id in OBJECTS.size():
		var thumb_name = THUMBS_PATH + str(obj_id) + ".png"
		if file.file_exists(thumb_name):
			Log.d(" - Found thumb: {}", thumb_name)
			OBJECTS[obj_id].thumb = create_image_texture(thumb_name)
		else:
			OBJECTS[obj_id].thumb = null

func reset():
	Log.d("Sending quad reset signal")
	emit_signal("reset")

func _process(_delta):
	if Input.is_action_just_pressed("reset"):
		reset()


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
	Log.d("Reading track definitions")
	var builtins = Globals.list_dir(BUILTIN_TRACKS_PATH)
	Log.d("Builtin tracks: {}", builtins)
	var tracks = Globals.list_dir(TRACK_PATH)
	Log.d("User tracks: {}", tracks)
	var dir = Directory.new()

	if tracks == null:
		Log.d("No user track folder, creating")
		dir.make_dir(TRACK_PATH)
		tracks = builtins
	else:
		for track in tracks:
			if builtins.has(track):
				Log.d(" - Removing duplicate builtin track: {}", track)
				builtins.erase(track)
		tracks += builtins

	if not dir.dir_exists(TRACK_THUMBS_PATH):
		dir.make_dir(TRACK_THUMBS_PATH)

	var file = File.new()
	for i in range(tracks.size()):
		var thumb = null
		var thumb_path = TRACK_THUMBS_PATH + tracks[i] + ".png"
		if file.file_exists(thumb_path):
			thumb = create_image_texture(thumb_path)
		tracks[i] = [tracks[i], thumb]
	return tracks


func _get_first_of_group(group):
	var nodes = get_tree().get_nodes_in_group(group)
	if nodes == null or nodes.size() == 0:
		return null
	return nodes[0]

func get_kwad() -> Spatial:
	return _get_first_of_group("Kwad")

func get_ui() -> Control:
	return _get_first_of_group("UI")

func get_track() -> Spatial:
	return _get_first_of_group("Track")
