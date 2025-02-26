extends Area2D

@export var location_id: String = "default_location"


func _ready():
	connect("input_event", Callable(self, "_on_input_event"))

func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		print("Выбрана локация: ", location_id)
		# Добавь сюда вызов функции для смены локации
		get_tree().call_group("game_manager", "move_to_location", location_id)
