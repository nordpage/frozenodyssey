extends Node2D

@export var location_scene: PackedScene
@export var title_label: Label
@export var description_label: Label
@export var event_panel: PanelContainer
@export var event_card_scene: PackedScene

@onready var event_manager = get_node_or_null("/root/Main/EventManager")
@onready var game_resources = get_node_or_null("/root/Main/GameResources")

var locations_data = []
var location_nodes = {}
var active_location_id: String = ""
var visited_locations = []
var last_location_id = ""

var resources = {
	"Temperature": 100,
	"Morale": 100,
	"Food": 100,
	"Energy": 100,
	"Speed": 5
}

func _ready():
	if not game_resources:
		print("❌ Ошибка: GameResources не найден в дереве!")
		return
		
	load_locations_from_json()
	draw_connections()
	
	if locations_data.size() > 0:
		var start_found = false
		for loc in locations_data:
			if loc["id"] == "start":
				update_active_location(loc["id"])
				start_found = true
				break
		
		if not start_found and locations_data.size() > 0:
			update_active_location(locations_data[0]["id"])
			
		disable_unreachable_locations()
		
	await get_tree().create_timer(0.1).timeout
	load_event_cards(active_location_id)
	
	
func save_game():
	SaveManager.save_game(self)
	
func load_game():
	return SaveManager.load_game(self)

func load_locations_from_json():
	var file = FileAccess.open("res://data/locations_new.json", FileAccess.READ)
	if not file:
		print("Ошибка: Не удалось открыть locations.json")
		return

	var json_text = file.get_as_text()
	var json = JSON.parse_string(json_text)

	if not json or not json.has("locations"):
		print("Ошибка: Неверный формат JSON")
		return

	locations_data = json["locations"]

	# Определяем границы карты
	var min_x = INF
	var min_y = INF
	var max_x = -INF
	var max_y = -INF

	for loc in locations_data:
		min_x = min(min_x, float(loc["position"]["x"]))
		min_y = min(min_y, float(loc["position"]["y"]))
		max_x = max(max_x, float(loc["position"]["x"]))
		max_y = max(max_y, float(loc["position"]["y"]))

	var center_x = (min_x + max_x) / 2
	var center_y = (min_y + max_y) / 2

	var screen_center = get_viewport_rect().size / 2
	var map_offset = Vector2(-screen_center.x * 0.2, -screen_center.y * 0.2)

	for loc in locations_data:
		loc["position"]["x"] = (float(loc["position"]["x"]) - center_x) * 150
		loc["position"]["y"] = (float(loc["position"]["y"]) - center_y) * 150

		loc["position"]["x"] += screen_center.x + map_offset.x
		loc["position"]["y"] += screen_center.y + map_offset.y
		
		create_location(loc)

func create_location(loc):
	var location_instance = location_scene.instantiate()
	add_child(location_instance)
	location_instance.default_texture = load("res://assets/location_icon.png")
	location_instance.active_texture = load("res://assets/location_icon_active.png")
	location_instance.disabled_texture = load("res://assets/location_icon_disabled.png")
	location_instance.position = Vector2(loc["position"]["x"], loc["position"]["y"])
	location_instance.location_id = loc["id"]
	location_instance.title = loc.get("title", "")
	location_instance.description = loc.get("description", "")
	location_instance.connect("location_selected", Callable(self, "_on_location_selected"))
	
	location_nodes[loc["id"]] = location_instance

func _on_location_selected(location_id: String):
	move_to_location(location_id)

func get_location_events(location_id):
	var cards = event_manager.get_location_cards(location_id)
	if cards.size() > 0:
		print("События для", location_id, ":", cards)
	else:
		print("Нет событий для", location_id)

func draw_connections():
	var path_lines = $Connections/PathLines
	path_lines.clear_points()
	
	var drawn_connections = {}

	for loc in locations_data:
		var start_node = location_nodes.get(loc["id"], null)
		if start_node:
			for connected_id in loc["connectedNodes"]:
				var end_node = location_nodes.get(connected_id, null)
				if end_node:
					var key = [loc["id"], connected_id]
					key.sort()  
					var key_str = key[0] + "-" + key[1]  

					if key_str in drawn_connections:
						continue  
					
					drawn_connections[key_str] = true

					path_lines.add_point(start_node.position)
					path_lines.add_point(end_node.position)

func update_active_location(location_id: String):
	if location_nodes.has(location_id):
		# Сбрасываем предыдущую активную точку
		for node in location_nodes.values():
			node.set_active(false)

		# Устанавливаем новую активную точку
		location_nodes[location_id].set_active(true)
		active_location_id = location_id

		# Обновляем текст локации
		var location_data = get_location_data(location_id)
		if location_data:
			title_label.text = location_data.get("title", "Unknown Location")
			description_label.text = location_data.get("description", "No description available.")
		
		# Загружаем карточки событий
		load_event_cards(location_id)
		disable_unreachable_locations()

func get_location_data(location_id: String) -> Dictionary:
	for loc in locations_data:
		if loc["id"] == location_id:
			return loc
	return {}

func load_event_cards(location_id: String):
	# Удаляем старые карточки
	for child in event_panel.get_children():
		child.queue_free()

	# Загружаем карточки событий
	if event_manager:
		var cards = event_manager.get_location_cards(location_id)
		if cards.size() > 0:
			for card in cards:
				create_event_card(card)

func create_event_button(card: Dictionary):
	var button = Button.new()
	button.text = card.get("title", "Unknown Event")
	button.tooltip_text = card.get("description", "No description available.")
	button.pressed.connect(func(): apply_event_effect(card))
	event_panel.add_child(button)
	
func create_event_card(card: Dictionary):
	if not event_card_scene:
		print("Ошибка: Префаб карточки событий не назначен!")
		return

	var event_card_instance = event_card_scene.instantiate()
	
	var title_node = event_card_instance.get_node_or_null("VBoxContainer/Title")
	var description_node = event_card_instance.get_node_or_null("VBoxContainer/Description")
	var apply_button = event_card_instance.get_node_or_null("VBoxContainer/ApplyButton")

	if not title_node or not description_node or not apply_button:
		print("❌ Ошибка: Проблема с нодами внутри карточки!")
		return

	title_node.text = card.get("title", "Unknown Event")
	description_node.text = card.get("description", "No description available.")

	apply_button.pressed.connect(func():
		apply_event_effect(card)
		event_card_instance.queue_free()
	)

	event_panel.add_child(event_card_instance)
	event_card_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_card_instance.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func move_to_location(location_id: String):
	print("Вызван move_to_location для:", location_id)
	print("Текущая активная точка:", active_location_id)
	
	if not location_nodes.has(location_id):
		print("❌ Точка не найдена:", location_id)
		return
		
	if location_id == active_location_id:
		print("⚠️ Точка уже активна:", location_id)
		disable_unreachable_locations()
		return

	# Проверяем энергию сначала
	if game_resources:
		var energy_resource = game_resources.get_resource("Energy")
		if energy_resource and energy_resource.amount < 10:
			print("❌ Недостаточно энергии для хода!")
			return

	print("🚶 Переход на точку:", location_id)

	# Запоминаем предыдущую локацию
	last_location_id = active_location_id
	
	# Добавляем в посещенные, если еще не добавлено
	if active_location_id != "" and not visited_locations.has(active_location_id):
		visited_locations.append(active_location_id)
	
	# Обновляем активную локацию
	if active_location_id != "":
		location_nodes[active_location_id].set_active(false)
	
	active_location_id = location_id
	location_nodes[active_location_id].set_active(true)

	# Обновляем UI
	var location_data = get_location_data(location_id)
	if location_data:
		title_label.text = location_data.get("title", "Unknown Location")
		description_label.text = location_data.get("description", "No description available.")

	# Загружаем карточки и затрачиваем энергию
	load_event_cards(location_id)
	if game_resources:
		game_resources.modify_resource("Energy", -10)

	print("🧩 Вызываем disable_unreachable_locations()")
	disable_unreachable_locations()
	print("✅ move_to_location завершен")

func disable_unreachable_locations():
	var active_location_data = get_location_data(active_location_id)
	if not active_location_data:
		return

	var accessible_nodes = active_location_data.get("connectedNodes", [])
	print("Доступные узлы от", active_location_id, ":", accessible_nodes)

	# Сначала активируем все точки, доступные от текущей
	for loc_id in location_nodes.keys():
		if loc_id == active_location_id:
			# Активная точка всегда активна
			location_nodes[loc_id].set_active(true)
		elif loc_id in accessible_nodes:
			# Соседние точки доступны для клика
			location_nodes[loc_id].set_enabled()
		else:
			# Остальные точки блокируем
			location_nodes[loc_id].set_disabled()
			
	# Затем блокируем все посещенные локации
	for prev_id in visited_locations:
		location_nodes[prev_id].set_disabled()
	

func apply_event_effect(card: Dictionary):
	var effect = card.get("effect", "")
	var value = card.get("value", 0)

	match effect:
		"temperature_gain":
			update_resource("Temperature", value)
		"temperature_loss":
			update_resource("Temperature", -value)
		"morale_boost":
			update_resource("Morale", value)
		"food_gain":
			update_resource("Food", value)
		"energy_gain":
			update_resource("Energy", value)
		"speed_boost":
			update_resource("Speed", value)
		"speed_loss":
			update_resource("Speed", -value)
		"move_block":
			print("Движение временно заблокировано!")

	print("Применен эффект:", effect, "значение:", value)
	AudioManager.play_sound("card_play")

func update_resource(resource: String, amount: int):
	if resources.has(resource):
		resources[resource] += amount
		print(resource, "изменено на", amount, "текущее значение:", resources[resource])

func show_event_card(event: EventCard):
	var event_card = event_card_scene.instantiate()
	add_child(event_card)
	event_card.setup(event, game_resources)
