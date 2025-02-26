extends Resource
class_name EventCard

@export var title: String = "Event Title"
@export var description: String = "Event Description"
@export var options: Array[Dictionary] = []

func apply_option(index: int, game_resources: GameResources):
	if index >= 0 and index < options.size():
		var option = options[index]
		for key in option["effects"]:
			game_resources.modify_resource(key, option["effects"][key])

		print("🎴 Выбрано:", option["text"], "→ Изменение:", option["effects"])
