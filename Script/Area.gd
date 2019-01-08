extends Area

func _ready():
	pass


func _on_Area_body_entered(body):
	print(body.name)
