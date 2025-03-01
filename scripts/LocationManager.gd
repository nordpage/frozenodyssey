extends Node

var locations = {}
var connections = {}
var cards = {}
var behaviors = {}

var actions_json_path: String = "res://data/actions_data.json"  # JSON с описанием карточек (25 действий)
var point_behaviors_json_path: String = "res://data/point_behaviors.json"  # JSON с привязкой карточек к точкам

var action_manager: ActionManager

func _ready():
	AudioManager.play_music("res://audio/ambient/arctic_theme.ogg", -20)
	load_locations()

func load_locations():
	var file = FileAccess.open("res://data/locations.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(json_text)
		if parse_result == OK:
			var data = json.get_data()
			for loc in data["locations"]:
				locations[loc["id"]] = loc
				connections[loc["id"]] = loc["connectedNodes"]
			print("Локации загружены: ", locations.keys())
		else:
			print("Ошибка загрузки JSON")
	else:
		print("Файл JSON не найден")
		
func load_actions():
	action_manager = ActionManager.new()
	action_manager.load_actions_from_json(actions_json_path)
	
	# Загрузим привязку карточек к точкам из JSON
	var file := FileAccess.open(point_behaviors_json_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		var result = json.parse(content)
		if result.error == OK:
			var data = json.get_data()
			for act in data["actions"]:
				cards[act["id"]] = act
		else:
			push_error("Ошибка парсинга point_behaviors JSON: %s" % result.error_string)
		file.close()
	else:
		push_error("Не удалось открыть файл: %s" % point_behaviors_json_path)
		
func load_behaviors():
	action_manager = ActionManager.new()
	action_manager.load_actions_from_json(actions_json_path)
	
	# Загрузим привязку карточек к точкам из JSON
	var file := FileAccess.open(point_behaviors_json_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		var result = json.parse(content)
		if result.error == OK:
			var data = json.get_data()
			for act in data["actions"]:
				cards[act["id"]] = act
		else:
			push_error("Ошибка парсинга point_behaviors JSON: %s" % result.error_string)
		file.close()
	else:
		push_error("Не удалось открыть файл: %s" % point_behaviors_json_path)
