extends Node2D

@export var location_scene: PackedScene
@export var title_label: Label
@export var description_label: Label
@onready var date_label = $"../CanvasLayer/Control/HUDContainer/DateContainer/DateValue"
@export var event_panel: PanelContainer
@export var event_card_scene: PackedScene
@export var camera_speed: float = 500.0

@onready var event_manager = get_node_or_null("/root/Main/EventManager")
@onready var game_resources = get_node_or_null("/root/Main/GameResources")
@onready var camera = $Camera2D

var locations_data = []
var location_nodes = {}
var active_location_id: String = ""
var visited_locations = []
var last_location_id = ""
var original_positions = {}
var hover_original_positions = {}
var is_expanded = false
var current_hover_id = ""

# Иерархия точек
var location_groups = {}
var main_locations = []
var sub_locations = {}
var current_date = "08.12.1912"
var visible_sub_locations = []

# Константы группировки
const GROUPING_THRESHOLD = 5
const ZOOM_THRESHOLD_FOR_DETAILS = 1.2

var resources = {
	"Temperature": 100,
	"Morale": 100,
	"Food": 100,
	"Energy": 100,
	"Speed": 5
}

var camera_move = Vector2.ZERO

func _ready():
	if not game_resources:
		print("❌ Ошибка: GameResources не найден в дереве!")
		return
		
	load_locations_from_json()
	group_locations_by_coordinates()
	debug_location_groups()
	store_original_positions()
	draw_connections()
	
	if locations_data.size() > 0:
		var initial_location_id = locations_data[0]["id"]
		update_active_location(initial_location_id)
		disable_unreachable_locations()
		
		if location_nodes.has(initial_location_id):
			move_camera_to_location(location_nodes[initial_location_id].position)

		if locations_data[0].has("date"):
			set_current_date(locations_data[0]["date"])
			
	unlock_first_location()


	await get_tree().create_timer(0.1).timeout
	load_event_cards(active_location_id)

func _process(delta):
	if camera_move != Vector2.ZERO:
		camera.position += camera_move * camera_speed * delta * (1.0 / camera.zoom.x)

func store_original_positions():
	for id in location_nodes:
		original_positions[id] = location_nodes[id].position

func parse_date(date_str: String) -> int:
	var parts = date_str.split(".")
	if parts.size() == 3:
		return int(parts[2]) * 10000 + int(parts[1]) * 100 + int(parts[0])
	return 0  # Если формат неправильный

func group_locations_by_coordinates():
	locations_data.sort_custom(func(a, b): return parse_date(a["date"]) < parse_date(b["date"]))

	var grouped_locations = {}
	var group_id = 0

	for loc in locations_data:
		var added = false

		for g_id in grouped_locations:
			var group = grouped_locations[g_id]
			var main_loc = group[0]

			if is_close_coordinates(loc["x"], loc["y"], main_loc["x"], main_loc["y"]):
				group.append(loc)
				added = true
				break

		if not added:
			grouped_locations[group_id] = [loc]
			group_id += 1

	for g_id in grouped_locations:
		var group = grouped_locations[g_id]
		var main_loc = group[0]
		main_locations.append(main_loc["id"])
		sub_locations[main_loc["id"]] = []
		location_groups[main_loc["id"]] = []

		for loc in group:
			location_groups[main_loc["id"]].append(loc["id"])

			if loc["id"] != main_loc["id"]:
				sub_locations[main_loc["id"]].append(loc["id"])

	update_connected_nodes_for_main_locations()

func is_close_coordinates(x1, y1, x2, y2) -> bool:
	var distance = sqrt(pow(x1 - x2, 2) + pow(y1 - y2, 2))
	return distance < GROUPING_THRESHOLD

func update_connected_nodes_for_main_locations():
	for main_id in main_locations:
		var connected_main_locations = []  # Изменено с словаря на массив

		for loc_id in location_groups[main_id]:
			var loc_data = get_location_data(loc_id)

			for connected_id in loc_data.get("connectedNodes", []):
				for other_main_id in main_locations:
					if other_main_id == main_id:
						continue

					if location_groups.has(other_main_id) and connected_id in location_groups[other_main_id]:
						if not other_main_id in connected_main_locations:  # Проверка на дубликаты
							connected_main_locations.append(other_main_id)

		for loc_data in locations_data:
			if loc_data["id"] == main_id:
				loc_data["connectedNodes"] = connected_main_locations

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
		min_x = min(min_x, float(loc["x"]))
		min_y = min(min_y, float(loc["y"]))
		max_x = max(max_x, float(loc["x"]))
		max_y = max(max_y, float(loc["y"]))

	var center_x = (min_x + max_x) / 2
	var center_y = (min_y + max_y) / 2

	var screen_center = get_viewport_rect().size / 2
	
	# Базовый масштаб для локаций
	var scaling_factor = 400
	var map_offset = Vector2(-screen_center.x * 0.2, -screen_center.y * 0.2)

	for loc in locations_data:
		loc["x"] = (float(loc["x"]) - center_x) * scaling_factor
		loc["y"] = (float(loc["y"]) - center_y) * scaling_factor

		loc["x"] += screen_center.x + map_offset.x
		loc["y"] += screen_center.y + map_offset.y
		
		create_location(loc)

func create_location(loc):
	# Проверяем, является ли локация главной
	var is_main_location = main_locations.has(loc["id"])
	
	var location_instance = location_scene.instantiate()
	add_child(location_instance)
	
	# Настройка текстур
	var sprite = location_instance.get_node("Sprite2D")
	if sprite:
		sprite.texture = load("res://assets/location_icon.png")
	
	location_instance.default_texture = load("res://assets/location_icon.png")
	location_instance.active_texture = load("res://assets/location_icon_active.png")
	location_instance.disabled_texture = load("res://assets/location_icon_disabled.png")
	
	location_instance.position = Vector2(loc["x"], loc["y"])
	location_instance.location_id = loc["id"]
	location_instance.title = loc.get("title", "")
	location_instance.description = loc.get("description", "")
	
	# Увеличиваем размер главных локаций
	if is_main_location:
		location_instance.scale = Vector2(1.5, 1.5)
	
	print("Подключение сигналов для локации: ", loc["id"])
	# Подключаем сигналы - исправляем названия сигналов
	location_instance.connect("location_selected", Callable(self, "_on_location_selected"))
	location_instance.connect("mouse_entered", Callable(self, "_on_mouse_entered").bind(loc["id"]))
	location_instance.connect("mouse_exited", Callable(self, "_on_mouse_exited").bind(loc["id"]))
	
	location_nodes[loc["id"]] = location_instance
	
	# Скрываем подлокации изначально
	if not is_main_location:
		location_instance.scale = Vector2(0.6, 0.6)
		location_instance.visible = false

func _on_location_selected(location_id: String):
	move_to_location(location_id)

func _on_mouse_entered(location_id):
	print("Наведение на локацию:", location_id)
	current_hover_id = location_id

	if main_locations.has(location_id):
		show_sub_locations(location_id)

func _on_mouse_exited(location_id):
	var hover_id_before_wait = current_hover_id
	await get_tree().create_timer(0.1).timeout

	if current_hover_id == hover_id_before_wait:
		reset_locations_positions()

	if main_locations.has(location_id):
		await get_tree().create_timer(0.4).timeout
		hide_sub_locations(location_id)

func move_camera_to_location(target_pos):
	if camera.has_meta("current_tween"):
		var old_tween = camera.get_meta("current_tween")
		if is_instance_valid(old_tween) and old_tween.is_valid():
			old_tween.kill()
		
	var tween = create_tween()
	camera.set_meta("current_tween", tween)
	
	tween.tween_property(camera, "position", target_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func move_to_location(location_id: String):
	if not location_nodes.has(location_id):
		return

	if location_id == active_location_id:
		disable_unreachable_locations()
		return

	last_location_id = active_location_id
	if active_location_id != "" and not visited_locations.has(active_location_id):
		visited_locations.append(active_location_id)

	if active_location_id != "":
		location_nodes[active_location_id].set_active(false)

	active_location_id = location_id
	location_nodes[active_location_id].set_active(true)

	move_camera_to_location(location_nodes[active_location_id].position)

	var location_data = get_location_data(location_id)
	if location_data:
		title_label.text = location_data.get("title", "Unknown Location")
		description_label.text = location_data.get("description", "No description available.")

		if date_label and location_data.has("date"):
			date_label.text = location_data["date"]
			set_current_date(location_data["date"])

	load_event_cards(location_id)

	if game_resources:
		game_resources.modify_resource("Energy", -10)

	disable_unreachable_locations()
	
	# Разблокируем следующую подлокацию, если все предыдущие пройдены
	unlock_next_sub_location(location_id)

	# Разблокируем следующую точку только если ВСЕ подлокации посещены
	if are_all_sub_locations_visited(location_id):
		unlock_next_location(location_id)




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
			
			# Обновляем дату, если установлен date_label
			if date_label and location_data.has("date"):
				date_label.text = location_data["date"]
				set_current_date(location_data["date"])
		
		# Загружаем карточки событий
		load_event_cards(location_id)
		disable_unreachable_locations()

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
			
			# Если это главная локация, проверяем, доступна ли она по дате
			if main_locations.has(loc_id):
				var loc_data = get_location_data(loc_id)
				if loc_data.has("date") and not is_date_passed(loc_data["date"], current_date):
					location_nodes[loc_id].set_disabled()
		else:
			# Остальные точки блокируем
			location_nodes[loc_id].set_disabled()
			
	# Затем блокируем все посещенные локации
	for prev_id in visited_locations:
		location_nodes[prev_id].set_disabled()

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

func reset_locations_positions():
	if not is_expanded:
		return

	is_expanded = false

	for id in hover_original_positions:
		var loc_node = location_nodes[id]
		var original_pos = hover_original_positions[id]
		
		var tween = create_tween()
		tween.tween_property(loc_node, "position", original_pos, 0.3).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(0.3).timeout
	draw_connections()

func set_current_date(new_date):
	current_date = new_date
	update_locations_visibility_by_date(current_date)

func get_location_data(location_id: String) -> Dictionary:
	for loc in locations_data:
		if loc["id"] == location_id:
			return loc
	return {}

func update_locations_visibility_by_date(current_date_str):
	current_date = current_date_str
	
	for loc in locations_data:
		var loc_id = loc["id"]
		var loc_date = loc["date"]

		if not loc.has("date") or loc_date.strip_edges() == "":
			continue

		if is_date_passed(loc_date, current_date):
			if main_locations.has(loc_id):
				location_nodes[loc_id].visible = true
		else:
			if location_nodes.has(loc_id):
				location_nodes[loc_id].visible = false

# Показ подлокаций вокруг главной локации
func show_sub_locations(main_location_id):
	if not sub_locations.has(main_location_id):
		print("⚠️ Нет подлокаций у", main_location_id)
		return

	# Показываем только если главная локация уже выбрана
	if active_location_id != main_location_id:
		print("❌ Главная локация не выбрана, не показываем подлокации")
		return

	var main_pos = location_nodes[main_location_id].position
	var subs = sub_locations[main_location_id]

	print("🔵 Показываем подлокации для:", main_location_id, "количество:", subs.size())

	for i in range(subs.size()):
		var sub_id = subs[i]

		if not location_nodes.has(sub_id):
			print("⚠️ Локация", sub_id, "не найдена в location_nodes")
			continue

		location_nodes[sub_id].visible = true
		visible_sub_locations.append(sub_id)

		# Вычисляем позицию для подлокаций
		var distance = 50.0
		var offset = Vector2.ZERO

		if subs.size() == 1:
			offset = Vector2(distance, -distance * 0.2)
		elif subs.size() == 2:
			var directions = [Vector2(1, -0.5), Vector2(-1, 0.5)]
			offset = directions[i] * distance
		else:
			var angle = (2 * PI / subs.size()) * i
			offset = Vector2(cos(angle), sin(angle)) * distance

		# Разблокируем только первую подлокацию, остальные пока недоступны
		if i == 0:
			location_nodes[sub_id].set_enabled()
		else:
			location_nodes[sub_id].set_disabled()

		# Анимация появления
		var tween = create_tween()
		location_nodes[sub_id].modulate.a = 0
		location_nodes[sub_id].position = main_pos
		tween.tween_property(location_nodes[sub_id], "position", main_pos + offset, 0.3)
		tween.parallel().tween_property(location_nodes[sub_id], "modulate:a", 1.0, 0.3)



# Скрытие подлокаций
func hide_sub_locations(main_location_id):
	if not sub_locations.has(main_location_id):
		return

	# Создаем массив подлокаций для скрытия и копируем его
	var subs_to_hide = []
	for sub_id in sub_locations[main_location_id]:
		if location_nodes.has(sub_id) and sub_id in visible_sub_locations:
			subs_to_hide.append(sub_id)
	
	# Выполняем скрытие для всех подлокаций в списке
	for sub_id in subs_to_hide:
		var tween = create_tween()
		var main_pos = location_nodes[main_location_id].position
		
		tween.tween_property(location_nodes[sub_id], "modulate:a", 0.0, 0.2)
		tween.finished.connect(func():
			if location_nodes.has(sub_id):
				location_nodes[sub_id].visible = false
				visible_sub_locations.erase(sub_id)
		)
		
func is_date_passed(date1, date2) -> bool:
	return parse_date(date1) <= parse_date(date2)

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

func draw_connections():
	var path_lines = $Connections/PathLines
	path_lines.clear_points()
	
	var drawn_connections = {}

	# Основная отрисовка соединений
	for loc in locations_data:
		var start_node = location_nodes.get(loc["id"], null)
		if start_node and start_node.visible:
			for connected_id in loc["connectedNodes"]:
				var end_node = location_nodes.get(connected_id, null)
				if end_node and end_node.visible:
					var key = [loc["id"], connected_id]
					key.sort()
					var key_str = key[0] + "-" + key[1]

					if key_str in drawn_connections:
						continue
					
					drawn_connections[key_str] = true

					path_lines.add_point(start_node.position)
					path_lines.add_point(end_node.position)

# Обработка ввода для движения камеры и зума
func _unhandled_input(event):
	# Масштабирование
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_camera(1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_camera(0.9)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Возвращение камеры к активной точке по правой кнопке мыши
			if active_location_id != "" and location_nodes.has(active_location_id):
				move_camera_to_location(location_nodes[active_location_id].position)
			
	# Управление клавишами WASD
	if event is InputEventKey:
		match event.keycode:
			KEY_W:
				camera_move.y = -1.0 if event.pressed else 0.0 if camera_move.y < 0 else camera_move.y
			KEY_S:
				camera_move.y = 1.0 if event.pressed else 0.0 if camera_move.y > 0 else camera_move.y
			KEY_A:
				camera_move.x = -1.0 if event.pressed else 0.0 if camera_move.x < 0 else camera_move.x
			KEY_D:
				camera_move.x = 1.0 if event.pressed else 0.0 if camera_move.x > 0 else camera_move.x

# Функция для масштабирования камеры
func zoom_camera(factor):
	var new_zoom = camera.zoom * factor
	# Ограничиваем масштаб
	new_zoom = new_zoom.clamp(Vector2(0.5, 0.5), Vector2(2, 2))
	
	var tween = create_tween()
	tween.tween_property(camera, "zoom", new_zoom, 0.1)
	
# Разблокировка следующей группы, если текущая завершена
func unlock_next_group():
	var unlocked = false

	for i in range(main_locations.size()):
		var main_id = main_locations[i]

		if main_id in visited_locations:
			continue  # Пропускаем уже посещенные
		
		# Проверяем, есть ли у группы подлокации
		if sub_locations.has(main_id) and sub_locations[main_id].size() > 0:
			var all_sub_visited = true
			
			for sub_id in sub_locations[main_id]:
				if not sub_id in visited_locations:
					all_sub_visited = false
					break
			
			if all_sub_visited:
				print("✅ Все подлокации посещены, разблокируем следующую главную:", main_id)
				location_nodes[main_id].set_enabled()
				unlocked = true
				break
		else:
			# Если у главной нет подлокаций - сразу разблокируем её
			print("✅ Локация", main_id, "не имеет подлокаций, разблокирована!")
			location_nodes[main_id].set_enabled()
			unlocked = true
			break

	if not unlocked:
		print("⚠️ Нет новых групп для разблокировки!")
		
func unlock_next_groups():
	var queue = [active_location_id]  # Очередь для обработки

	while queue.size() > 0:
		var loc_id = queue.pop_front()

		if loc_id in main_locations and sub_locations.get(loc_id, []).size() == 0:
			print("✅ Группа", loc_id, "не имеет подлокаций, ищем следующую точку...")

			var loc_data = get_location_data(loc_id)
			if not loc_data:
				continue

			var accessible_nodes = loc_data.get("connectedNodes", [])
			print("➡ Следующие доступные точки:", accessible_nodes)

			var unlocked = false

			for next_id in accessible_nodes:
				if location_nodes.has(next_id) and not location_nodes[next_id].visible:
					print("✅ Разблокирована точка:", next_id)
					location_nodes[next_id].set_enabled()
					location_nodes[next_id].visible = true  # Открыть точку
					unlocked = true
					queue.append(next_id)  # Добавляем в очередь для проверки

			# Если что-то изменилось, обновляем соединения
			if unlocked:
				draw_connections()

		
# Разблокировать следующую доступную точку, если текущая не имеет подлокаций
# Разблокировать следующую доступную точку, если текущая не имеет подлокаций
func unlock_next_location(current_location):
	if not are_all_sub_locations_visited(current_location):
		return

	var current_data = get_location_data(current_location)
	if not current_data:
		return

	var accessible_nodes = current_data.get("connectedNodes", [])
	print("➡ Следующие доступные точки:", accessible_nodes)

	var unlocked = false

	for loc_id in accessible_nodes:
		if location_nodes.has(loc_id) and not location_nodes[loc_id].visible:
			print("✅ Разблокирована точка:", loc_id)
			location_nodes[loc_id].set_enabled()
			location_nodes[loc_id].visible = true
			unlocked = true

	if unlocked:
		draw_connections()


func unlock_first_location():
	if main_locations.size() == 0:
		return

	var first_main_id = main_locations[0]

	# Если у первой точки нет подлокаций - разблокируем следующую
	if sub_locations.get(first_main_id, []).size() == 0:
		print("✅ Первая локация", first_main_id, "не имеет подлокаций, разблокируем следующую...")
		unlock_next_location(first_main_id)
		
func unlock_next_sub_location(main_location_id):
	if not sub_locations.has(main_location_id):
		return

	var subs = sub_locations[main_location_id]

	for sub_id in subs:
		if sub_id in visited_locations:
			continue

		if location_nodes.has(sub_id):
			print("✅ Разблокирована подлокация:", sub_id)
			location_nodes[sub_id].set_enabled()
		break  # Разблокируем только ОДНУ подлокацию за раз


func are_all_sub_locations_visited(main_location_id) -> bool:
	if not sub_locations.has(main_location_id):
		return true  # Если подлокаций нет - сразу да

	for sub_id in sub_locations[main_location_id]:
		if sub_id not in visited_locations:
			return false  # Нашли непосещенную подлокацию
	
	return true  # Все подлокации пройдены

	
func debug_location_groups():
	print("==== ОТЛАДКА ГРУПП ЛОКАЦИЙ ====")
	print("Всего локаций: ", locations_data.size())
	print("Всего главных локаций: ", main_locations.size())
	
	for main_id in main_locations:
		var sub_count = 0
		if sub_locations.has(main_id):
			sub_count = sub_locations[main_id].size()
		print("Главная локация: ", main_id, ", подлокаций: ", sub_count)
		
		if sub_locations.has(main_id):
			for sub_id in sub_locations[main_id]:
				print("  - Подлокация: ", sub_id)
	
	print("===== КОНЕЦ ОТЛАДКИ =====")
