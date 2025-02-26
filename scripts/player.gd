extends CharacterBody2D

@export var speed = 300
@onready var map = get_node("./map") # Убедись, что название совпадает в сцене!
var current_location = "start"

func move_to(target_position):
	var tween = create_tween()
	tween.tween_property(self, "position", target_position, 0.5).set_trans(Tween.TRANS_LINEAR)
	await tween.finished

	# Проверяем, существует ли метод get_location_at() в объекте map
	if map.has_method("get_location_at"):
		current_location = map.get_location_at(target_position)
	else:
		push_error("Ошибка: метод get_location_at() не найден в Map.gd!")
