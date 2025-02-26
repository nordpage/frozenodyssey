extends Node

var locations = {}
var connections = {}

func _ready():
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
