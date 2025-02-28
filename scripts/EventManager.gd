extends Node
class_name EventManager

var event_cards: Dictionary = {}

func _ready():
	load_event_cards()

func load_event_cards():
	var file = FileAccess.open("res://data/location_cards.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var json_data = JSON.parse_string(json_text)

		if json_data and "locationCards" in json_data:
			for location in json_data["locationCards"]:
				var location_id = location["locationId"]
				event_cards[location_id] = []

				for card_data in location["cards"]:
					var card = EventCard.new()
					card.id = card_data["id"]
					card.title = card_data["title"]
					card.title_en = card_data["title_en"]
					card.description = card_data["description"]
					card.description_en = card_data["description_en"]
					card.effect = card_data["effect"]
					card.value = card_data["value"]

					event_cards[location_id].append(card)
	
	print("✅ Event cards loaded successfully!")
	
