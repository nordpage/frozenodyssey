extends Node

var events_data = {}

func _ready():
	load_events()

func load_events():
	var file = FileAccess.open("res://data/location_cards.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var json = JSON.parse_string(json_text)
		if json and "locationCards" in json:
			events_data = {}
			for entry in json["locationCards"]:
				events_data[entry["locationId"]] = entry["cards"]
		file.close()
	else:
		print("Ошибка загрузки events.json")

# Получение всех карточек для конкретной локации
func get_location_cards(location_id):
	if location_id in events_data:
		return events_data[location_id]
	return []
