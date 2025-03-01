extends Node
class_name ActionManager

var actions: Dictionary = {}

func load_actions_from_json(json_path: String) -> void:
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		var result = json.parse(content)
		if result.error == OK:
			for action_data in result.result:
				# Создаем экземпляр ActionCard, передавая параметры из action_data
				var card = ActionCard.new(
					action_data["id"],
					action_data["title"],
					action_data["title_en"],
					action_data["description"],
					action_data["description_en"],
					action_data["boost"],
					int(action_data["points"])
				)
				actions[card.id] = card
		else:
			push_error("Ошибка парсинга JSON: %s" % result.error_string)
		file.close()
	else:
		push_error("Не удалось открыть файл: %s" % json_path)

func get_action(action_id: String) -> ActionCard:
	if actions.has(action_id):
		return actions[action_id]
	return null

func list_actions() -> Array:
	return actions.values()
