extends Node

const LOGS_PATH = "user://Logs/"

var log_path = null
var log_file = null

func _to_str(type, msg, values):
	if typeof(msg) != TYPE_STRING:
		values = [msg]
		msg = "{}"
		
	if typeof(values) != TYPE_ARRAY:
		values = [values]
	
	var s = msg.format(values, "{}")
	var t = OS.get_ticks_msec()
	return "[%05d.%03d] [%s] %s" % [t / 1000, t % 1000, type, s]

func _log(type, msg, values):
	var s = _to_str(type, msg, values)
	log_file.store_string(s + '\n')
	print(s)
	
func d(msg, values = []):
	_log("DEBUG", msg, values)

func i(msg, values = []):
	_log(" INFO", msg, values)

func e(msg, values = []):
	_log("ERROR", msg, values)


func _ready():
	var dir = Directory.new()
	if not dir.dir_exists(LOGS_PATH):
		print("No Log folder, creating")
		dir.make_dir(LOGS_PATH)
	
	var date = OS.get_datetime()
	log_path = LOGS_PATH + "%02d%02d%02d_%02d%02d%02d.log" % \
		[date.year, date.month, date.day, date.hour, date.minute, date.second]

	log_file = File.new()
	log_file.open(log_path, File.WRITE)
	
	Log.d("Log file saving to {}", [log_path])

func _exit_tree():
	if log_file.is_open():
		log_file.close()