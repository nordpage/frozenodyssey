extends Node2D

@export var title_label: Label
@export var description_label: Label
@export var diary_label: Label
@export var date_label: Label
@export var event_panel: HBoxContainer
@export var event_card_scene: PackedScene
@export var camera_speed: float = 500.0

@onready var event_manager = get_node_or_null("/root/Main/EventManager")
@onready var game_resources = get_node_or_null("/root/Main/GameResources")
@onready var camera = $Camera2D

var expedition_data = {}
var location_nodes = {}
var cards = {}
var behaviors = {}
var active_location_id: String = ""
var visited_locations = []
var last_location_id = ""
var original_positions = {}
var current_date = "08.12.1912"
var camera_move = Vector2.ZERO

var info_panel_container = null



# Кэш текстур
var texture_cache = {}

# Константы для отображения
const HORIZONTAL_SPACING = 180.0
const VERTICAL_SPACING = 80.0
const CONNECTION_COLORS = {
	"expedition": Color(1.0, 0.8, 0.2),
	"stage": Color(0.2, 0.8, 1.0),
	"group": Color(0.8, 0.2, 1.0),
	"point": Color(0.5, 0.5, 0.5)
}

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
	
	# Загружаем текстуры в кэш для оптимизации
	preload_textures()
	
	# Создаем узел для соединений, если его еще нет
	if not has_node("Connections"):
		var connections = Node2D.new()
		connections.name = "Connections"
		add_child(connections)
	
	# Загружаем данные и создаем ноды
	load_expedition_data()
	create_location_nodes_linear()
	load_actions()
	load_behaviors()
	
	set_total_war_visibility()
	
	if event_panel:
		event_panel.visible = false
	
	# Устанавливаем начальную локацию
	var initial_id = "expedition"
	if expedition_data.has("levels") and expedition_data["levels"].size() > 0:
		initial_id = "expedition" # Начальная точка - экспедиция
	
	set_active_location(initial_id)
	update_visible_locations()
	
	# Перемещаем камеру к начальной локации
	if location_nodes.has(initial_id):
		move_camera_to_location(location_nodes[initial_id].position)
	
	# Устанавливаем начальную дату
	if expedition_data.has("levels") and expedition_data["levels"].size() > 0 and expedition_data["levels"][0].has("date_range"):
		var date_parts = expedition_data["levels"][0]["date_range"].split(" – ")
		if date_parts.size() > 0:
			set_current_date(date_parts[0])
	
	# Отрисовываем соединения для видимых элементов
	draw_connections()
	
	# Дополнительная отладочная информация
	print_debug_info()
	style_all_ui_elements()
	
	
func set_total_war_visibility():
	for loc_id in location_nodes.keys():
		var node = location_nodes[loc_id]
		
		match node.location_type:
			"expedition":
				node.visible = true
				node.set_active(true)
				node.is_expanded = true
				
			"stage":
				# Все этапы видны
				node.visible = true
				
				# Только первый этап активен
				var first_stage_id = ""
				if expedition_data.has("levels") and expedition_data["levels"].size() > 0:
					first_stage_id = expedition_data["levels"][0]["id"]
				
				if loc_id == first_stage_id:
					node.set_enabled()
				else:
					node.set_disabled()
					
			"group", "point":
				# Группы и точки скрыты по умолчанию
				node.visible = false
				node.set_disabled()
	
	draw_connections()

# Предзагрузка текстур для повышения производительности
func preload_textures():
	texture_cache = {
		"expedition": {
			"default": preload("res://assets/expedition_icon.png"),
			"active": preload("res://assets/expedition_icon_active.png"),
			"disabled": preload("res://assets/expedition_icon_disabled.png")
		},
		"stage": {
			"default": preload("res://assets/stage_icon.png"),
			"active": preload("res://assets/stage_icon_active.png"),
			"disabled": preload("res://assets/stage_icon_disabled.png")
		},
		"group": {
			"default": preload("res://assets/group_icon.png"),
			"active": preload("res://assets/group_icon_active.png"),
			"disabled": preload("res://assets/group_icon_disabled.png")
		},
		"point": {
			"default": preload("res://assets/location_icon.png"),
			"active": preload("res://assets/location_icon_active.png"),
			"disabled": preload("res://assets/location_icon_disabled.png")
		}
	}

func _process(delta):
	if camera_move != Vector2.ZERO:
		camera.position += camera_move * camera_speed * delta * (1.0 / camera.zoom.x)

# Загрузка данных экспедиции из JSON
func load_expedition_data():
	print("Загрузка данных экспедиции...")
	var file_path = "res://data/expedition_data.json"
	
	if not FileAccess.file_exists(file_path):
		print("❌ Ошибка: Файл не найден:", file_path)
		return
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("❌ Ошибка: Не удалось открыть файл:", file_path)
		return

	var json_text = file.get_as_text()
	print("Чтение данных JSON:", json_text.substr(0, 100) + "...")
	
	var json = JSON.parse_string(json_text)
	if not json:
		print("❌ Ошибка: Неверный формат JSON")
		return

	if not json.has("expedition"):
		print("❌ Ошибка: Нет ключа 'expedition' в JSON")
		return

	expedition_data = json["expedition"]
	print("✅ Данные экспедиции загружены:", expedition_data["name"])
	
func load_actions():
	print("Загрузка карточек...")
	var file_path = "res://data/actions_data.json"
	
	if not FileAccess.file_exists(file_path):
		print("❌ Ошибка: Файл не найден:", file_path)
		return
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("❌ Ошибка: Не удалось открыть файл:", file_path)
		return

	var json_text = file.get_as_text()
	print("Чтение данных JSON:", json_text.substr(0, 100) + "...")
	
	var json = JSON.parse_string(json_text)
	if not json:
		print("❌ Ошибка: Неверный формат JSON")
		return

	if not json.has("actions"):
		print("❌ Ошибка: Нет ключа 'actions' в JSON")
		return

	cards = json["actions"]
		
func load_behaviors():
	print("Loading point behaviors...")
	var file_path = "res://data/point_behaviors.json"
	
	if not FileAccess.file_exists(file_path):
		print("❌ Error: File not found:", file_path)
		return
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("❌ Error: Could not open file:", file_path)
		return

	var json_text = file.get_as_text()
	print("Reading JSON data:", json_text.substr(0, 100) + "...")
	
	var json = JSON.parse_string(json_text)
	if not json:
		print("❌ Error: Invalid JSON format")
		return

	if not json.has("behaviors"):
		print("❌ Error: No 'behaviors' key in JSON")
		return

	behaviors = json["behaviors"]
	print("✅ Loaded behaviors for", behaviors.size(), "points")
	
	# Debugging - print what was loaded
	for behavior in behaviors:
		print("Point:", behavior.get("point_id", "unknown"), "has", behavior.get("behaviors", []).size(), "actions")
	
# Создание нод локаций в линейном расположении
func create_location_nodes_linear():
	if expedition_data.size() == 0:
		print("❌ Нет данных для создания локаций")
		return

	var screen_center = get_viewport_rect().size / 2
	var start_x = screen_center.x / 2
	var start_y = 100
	
	# Создаем ноду экспедиции
	var expedition_scene = load("res://scenes/ExpeditionPoint.tscn")
	var expedition_node = expedition_scene.instantiate()
	add_child(expedition_node)
	
	expedition_node.position = Vector2(start_x, start_y)
	expedition_node.location_id = "expedition"
	expedition_node.title = expedition_data["name"]
	expedition_node.description = expedition_data.get("description", "")
	
	# Подключаем сигналы
	expedition_node.connect("location_selected", Callable(self, "_on_location_selected"))
	expedition_node.connect("location_mouse_enter", Callable(self, "_on_location_mouse_enter"))
	expedition_node.connect("location_mouse_exit", Callable(self, "_on_location_mouse_exit"))
	expedition_node.connect("location_expand", Callable(self, "_on_location_expand"))
	expedition_node.connect("location_collapse", Callable(self, "_on_location_collapse"))
	
	location_nodes["expedition"] = expedition_node
	original_positions["expedition"] = expedition_node.position
	
	# Установка дочерних элементов для экспедиции
	if expedition_data.has("levels"):
		var children_ids = []
		for level in expedition_data["levels"]:
			children_ids.append(level["id"])
		expedition_node.set_children(children_ids)
	
	# Изначально все дочерние элементы скрыты
	create_stages_linear(expedition_data.get("levels", []), start_x + HORIZONTAL_SPACING, start_y)

# Создание этапов в линейном расположении
func create_stages_linear(stages, start_x, start_y):
	var y_pos = start_y
	
	for stage in stages:
		var stage_scene = load("res://scenes/StagePoint.tscn")
		var stage_node = stage_scene.instantiate()
		add_child(stage_node)
		
		stage_node.position = Vector2(start_x, y_pos)
		stage_node.location_id = stage["id"]
		stage_node.title = stage["title"]
		stage_node.description = stage.get("description", "")
		stage_node.date_range = stage.get("date_range", "")
		stage_node.parent_id = "expedition"
		
		# Координаты для навигации
		if stage.has("coordinates") and stage["coordinates"].size() >= 2:
			stage_node.coordinates = Vector2(stage["coordinates"][0], stage["coordinates"][1])
		
		# Подключаем сигналы
		stage_node.connect("location_selected", Callable(self, "_on_location_selected"))
		stage_node.connect("location_mouse_enter", Callable(self, "_on_location_mouse_enter"))
		stage_node.connect("location_mouse_exit", Callable(self, "_on_location_mouse_exit"))
		stage_node.connect("location_expand", Callable(self, "_on_location_expand"))
		stage_node.connect("location_collapse", Callable(self, "_on_location_collapse"))
		
		location_nodes[stage["id"]] = stage_node
		original_positions[stage["id"]] = stage_node.position
		
		# Изначально этапы скрыты
		stage_node.visible = false
		
		# Установка дочерних элементов для этапа
		if stage.has("children"):
			var children_ids = []
			for group in stage["children"]:
				children_ids.append(group["id"])
			stage_node.set_children(children_ids)
			
			# Создаем группы для этого этапа
			create_groups_linear(stage["children"], start_x + HORIZONTAL_SPACING, y_pos, stage["id"])
		
		# Увеличиваем Y-позицию для следующего этапа
		y_pos += VERTICAL_SPACING * 2

# Создание групп в линейном расположении
func create_groups_linear(groups, start_x, start_y, parent_id):
	var y_pos = start_y - VERTICAL_SPACING / 2  # Смещаем первую группу немного выше
	
	for group in groups:
		var group_scene = load("res://scenes/GroupPoint.tscn")
		var group_node = group_scene.instantiate()
		add_child(group_node)
		
		group_node.position = Vector2(start_x, y_pos)
		group_node.location_id = group["id"]
		group_node.title = group["title"]
		group_node.description = group.get("description", "")
		group_node.date_range = group.get("date_range", "")
		group_node.parent_id = parent_id
		
		# Координаты для навигации
		if group.has("coordinates") and group["coordinates"].size() >= 2:
			group_node.coordinates = Vector2(group["coordinates"][0], group["coordinates"][1])
		
		# Подключаем сигналы
		group_node.connect("location_selected", Callable(self, "_on_location_selected"))
		group_node.connect("location_mouse_enter", Callable(self, "_on_location_mouse_enter"))
		group_node.connect("location_mouse_exit", Callable(self, "_on_location_mouse_exit"))
		group_node.connect("location_expand", Callable(self, "_on_location_expand"))
		group_node.connect("location_collapse", Callable(self, "_on_location_collapse"))
		
		location_nodes[group["id"]] = group_node
		original_positions[group["id"]] = group_node.position
		
		# Изначально группы скрыты
		group_node.visible = false
		
		# Установка дочерних элементов для группы
		if group.has("children"):
			var children_ids = []
			for point in group["children"]:
				children_ids.append(point["id"])
			group_node.set_children(children_ids)
			
			# Создаем точки для этой группы
			create_points_linear(group["children"], start_x + HORIZONTAL_SPACING, y_pos, group["id"])
		
		# Увеличиваем Y-позицию для следующей группы
		y_pos += VERTICAL_SPACING * 1.5

# Создание точек в линейном расположении
# Создание точек в линейном расположении
func create_points_linear(points, start_x, start_y, parent_id):
	var y_pos = start_y - VERTICAL_SPACING / 2  # Смещаем первую точку немного выше
	
	for point in points:
		var point_scene = load("res://scenes/PointLocation.tscn")
		var point_node = point_scene.instantiate()
		add_child(point_node)
		
		point_node.position = Vector2(start_x, y_pos)
		point_node.location_id = point["id"]
		point_node.title = point["title"]
		point_node.title_en = point["title_en"]
		point_node.description = point.get("description", "")
		point_node.description_en = point.get("description_en", "")
		point_node.date_range = point.get("date", "")
		point_node.parent_id = parent_id
		
		# Явно устанавливаем интерактивность для точек
		point_node.input_pickable = true
		point_node.set_process_input(true)
		
		# Дневниковая запись
		if point.has("diary"):
			point_node.diary = point["diary"]
			point_node.diary_en = point["diary_en"]
		
		# Координаты для навигации
		if point.has("coordinates") and point["coordinates"].size() >= 2:
			point_node.coordinates = Vector2(point["coordinates"][0], point["coordinates"][1])
		
		# Подключаем сигналы
		point_node.connect("location_selected", Callable(self, "_on_location_selected"))
		point_node.connect("location_mouse_enter", Callable(self, "_on_location_mouse_enter"))
		point_node.connect("location_mouse_exit", Callable(self, "_on_location_mouse_exit"))
		
		# Установка связанных точек
		if point.has("connected_to"):
			point_node.set_children(point["connected_to"])
		
		location_nodes[point["id"]] = point_node
		original_positions[point["id"]] = point_node.position
		
		# Изначально все точки скрыты
		point_node.visible = false
		
		# По умолчанию все точки заблокированы, кроме первой в группе
		if points.find(point) == 0:
			# Первая точка в группе будет разблокирована изначально
			point_node.set_enabled()
		else:
			point_node.set_disabled()
		
		# Увеличиваем Y-позицию для следующей точки
		y_pos += VERTICAL_SPACING

# Обработка сигналов
# In map.gd
# map.gd - _on_location_selected
func _on_location_selected(location_id: String):
	print("Локация выбрана:", location_id)
	
	if not location_nodes.has(location_id):
		return
	
	var selected_node = location_nodes[location_id]
	
	# Проверяем, заблокирована ли локация
	if selected_node.is_disabled:
		print("Нельзя выбрать заблокированную локацию:", location_id)
		return
	
	# Сбрасываем предыдущую активную локацию того же типа
	var previous_active_id = active_location_id
	if previous_active_id != "" and location_nodes.has(previous_active_id):
		var previous_node = location_nodes[previous_active_id]
		if previous_node.location_type == selected_node.location_type:
			previous_node.set_active(false)
	
	# Устанавливаем новую активную локацию
	active_location_id = location_id
	selected_node.set_active(true)
	
	if selected_node.location_type == "stage" and selected_node.is_expanded:
		for i in range(selected_node.children_ids.size()):
			var child_id = selected_node.children_ids[i]
			if location_nodes.has(child_id) and location_nodes[child_id].location_type == "group":
				if i == 0:
					# Разблокируем только первую группу
					location_nodes[child_id].set_enabled()
				else:
					location_nodes[child_id].set_disabled()
					
	# Если выбрана группа, активируем первую точку
	if selected_node.location_type == "group" and selected_node.has_children:
		var first_point_id = ""
		if selected_node.children_ids.size() > 0:
			first_point_id = selected_node.children_ids[0]
			
		if location_nodes.has(first_point_id) and location_nodes[first_point_id].location_type == "point":
			location_nodes[first_point_id].set_enabled()
	
	# Если выбрана точка, добавляем её в посещенные и показываем карточки
	if selected_node.location_type == "point":
		# Сначала делаем панель видимой
		if event_panel:
			event_panel.visible = true
			
			# Очищаем существующие карточки
			var hbox = event_panel.get_node_or_null("HBoxContainer")
			if hbox:
				for child in hbox.get_children():
					child.queue_free()
			else:
				# Если HBoxContainer еще не создан, очищаем все прямые дочерние элементы
				for child in event_panel.get_children():
					if child.name != "CardTitle":  # Не удаляем заголовок
						child.queue_free()
		
		# Добавляем точку в посещенные и создаем карточки
		if not visited_locations.has(location_id):
			visited_locations.append(location_id)
			
			# Находим и показываем карточки для этой точки
			for entry in behaviors:
				if entry["point_id"] == location_id:
					var loc_actions = []
					for beh in entry["behaviors"]:
						for card in cards:
							if card["id"] == beh:
								create_event_card(card)
								loc_actions.append(card)
					print("Карточки действий для точки:", loc_actions)
			
			# Разблокируем следующую точку в группе
			unlock_next_point_in_group(selected_node.parent_id)
	else:
		# Скрываем панель, если выбрана не точка
		if event_panel:
			event_panel.visible = false
	
	# Перемещаем камеру к выбранной локации
	move_camera_to_location(selected_node.position)
	
	# Обеспечиваем видимость выбранной локации и её родителей
	ensure_hierarchy_visible(location_id)
	
	# Обновляем интерфейс
	update_ui_with_location_data(location_id)
	
	# Обновляем видимость локаций
	update_visible_locations()
	
	# Стилизуем карточки при необходимости
	if selected_node.location_type == "point":
		style_card_panel()
	
	# Стилизуем информационную панель
	style_expedition_info()	
	# Перерисовываем соединения
	draw_connections()
	
# map.gd - unlock_next_point_in_group и поддержка разблокировки следующего этапа
func unlock_next_point_in_group(group_id: String):
	if not location_nodes.has(group_id):
		return
		
	var group_node = location_nodes[group_id]
	if group_node.location_type != "group":
		return
	
	var points_in_group = []
	var all_visited = true
	
	# Собираем все точки в группе
	for child_id in group_node.children_ids:
		if location_nodes.has(child_id) and location_nodes[child_id].location_type == "point":
			points_in_group.append(child_id)
			# Проверяем, все ли точки посещены
			if not visited_locations.has(child_id):
				all_visited = false
	
	if not all_visited:
		# Находим последнюю посещенную точку
		var last_visited_index = -1
		for i in range(points_in_group.size()):
			if visited_locations.has(points_in_group[i]):
				last_visited_index = i
		
		# Если есть следующая точка - разблокируем её
		if last_visited_index < points_in_group.size() - 1:
			var next_point_id = points_in_group[last_visited_index + 1]
			location_nodes[next_point_id].set_enabled()
			print("✅ Разблокирована следующая точка:", next_point_id)
	else:
		# Если все точки в группе посещены - разблокируем следующую группу
		unlock_next_group(group_node.parent_id, group_id)
		
func unlock_next_group(stage_id: String, current_group_id: String):
	if not location_nodes.has(stage_id):
		return
		
	var stage_node = location_nodes[stage_id]
	if stage_node.location_type != "stage":
		return
	
	# Находим индекс текущей группы
	var current_index = stage_node.children_ids.find(current_group_id)
	if current_index == -1:
		return
	
	# Если есть следующая группа - разблокируем её
	if current_index < stage_node.children_ids.size() - 1:
		var next_group_id = stage_node.children_ids[current_index + 1]
		if location_nodes.has(next_group_id):
			location_nodes[next_group_id].set_enabled()
			print("✅ Разблокирована следующая группа:", next_group_id)
			
			# Разблокируем первую точку в новой группе
			if location_nodes[next_group_id].has_children:
				var children = location_nodes[next_group_id].children_ids
				if children.size() > 0 and location_nodes.has(children[0]):
					location_nodes[children[0]].set_enabled()
					print("✅ Разблокирована первая точка в новой группе:", children[0])
	
	# Если это была последняя группа в этапе - разблокируем следующий этап
	elif current_index == stage_node.children_ids.size() - 1:
		unlock_next_stage(stage_id)
		
func unlock_next_stage(current_stage_id: String):
	# Находим корневую экспедицию
	var expedition_id = "expedition"
	if not location_nodes.has(expedition_id):
		return
		
	var expedition_node = location_nodes[expedition_id]
	
	# Находим индекс текущего этапа
	var current_index = expedition_node.children_ids.find(current_stage_id)
	if current_index == -1:
		return
	
	# Если есть следующий этап - разблокируем его
	if current_index < expedition_node.children_ids.size() - 1:
		var next_stage_id = expedition_node.children_ids[current_index + 1]
		if location_nodes.has(next_stage_id):
			location_nodes[next_stage_id].set_enabled()
			print("✅ Разблокирован следующий этап:", next_stage_id)
			
			# Разблокируем первую группу в новом этапе
			if location_nodes[next_stage_id].has_children:
				var children = location_nodes[next_stage_id].children_ids
				if children.size() > 0 and location_nodes.has(children[0]):
					location_nodes[children[0]].set_enabled()
					print("✅ Разблокирована первая группа в новом этапе:", children[0])
					
					# И первую точку в этой группе
					var first_group = location_nodes[children[0]]
					if first_group.has_children and first_group.children_ids.size() > 0:
						var first_point_id = first_group.children_ids[0]
						if location_nodes.has(first_point_id):
							location_nodes[first_point_id].set_enabled()
							print("✅ Разблокирована первая точка в новой группе:", first_point_id)
	
	# Если это был последний этап - вывести сообщение о завершении
	elif current_index == expedition_node.children_ids.size() - 1:
		print("🎉 Все этапы экспедиции пройдены!")

func _on_location_mouse_enter(location_id: String):
	print("Наведение на локацию:", location_id)
	highlight_connections(location_id)

func _on_location_mouse_exit(location_id: String):
	reset_connections_highlight()

func _on_location_expand(location_id: String):
	print("Раскрытие локации:", location_id)
	if location_nodes.has(location_id):
		var node = location_nodes[location_id]
		node.is_expanded = true
		expand_location(location_id)

# В map.gd - _on_location_collapse
func _on_location_collapse(location_id: String):
	print("Сворачивание локации:", location_id)
	if location_nodes.has(location_id):
		var node = location_nodes[location_id]
		node.is_expanded = false
		
		# Важно: сначала устанавливаем default состояние иконки
		# Возвращаем стандартное состояние (default)
		if node.is_active:
			node.set_active(false)
			node.set_enabled()  # Это устанавливает default внешний вид
		
		# Затем скрываем дочерние элементы
		collapse_location(location_id)

# Новые вспомогательные функции
func show_direct_children(node_id: String):
	if not location_nodes.has(node_id):
		return
		
	var node = location_nodes[node_id]
	
	for child_id in node.children_ids:
		if location_nodes.has(child_id):
			location_nodes[child_id].visible = true
			print("Показываем узел:", child_id)

func hide_all_tree(node_id: String):
	if not location_nodes.has(node_id):
		return
		
	var node = location_nodes[node_id]
	
	for child_id in node.children_ids:
		if location_nodes.has(child_id):
			location_nodes[child_id].visible = false
			
			# Если у узла есть свои дети
			if location_nodes[child_id].is_expanded:
				hide_all_tree(child_id)

# Выделение связей локации при наведении
func highlight_connections(location_id: String):
	# Находим все соединения для данной локации
	for line in $Connections.get_children():
		if line is Line2D:
			var start_id = line.get_meta("start_id", "")
			var end_id = line.get_meta("end_id", "")
			
			if start_id == location_id or end_id == location_id:
				line.default_color = Color(1, 1, 0)  # Желтый цвет для выделения

# Сброс выделения соединений
func reset_connections_highlight():
	for line in $Connections.get_children():
		if line is Line2D:
			var type = line.get_meta("type", "point")
			line.default_color = CONNECTION_COLORS.get(type, Color(0.5, 0.5, 0.5))

# Отрисовка соединений между локациями
# В функции draw_connections добавьте проверку видимости
# Полностью переработанная функция draw_connections
func draw_connections():
	# Удаляем старые соединения
	for child in $Connections.get_children():
		child.queue_free()
	
	# Сначала собираем все соединения
	var connections_to_draw = []
	
	for loc_id in location_nodes.keys():
		var node = location_nodes[loc_id]
		
		# Пропускаем скрытые ноды
		if not node.visible:
			continue
		
		# Соединения с видимыми дочерними элементами
		if node.is_expanded:
			for child_id in node.children_ids:
				if location_nodes.has(child_id) and location_nodes[child_id].visible:
					connections_to_draw.append({
						"start": node,
						"end": location_nodes[child_id],
						"type": node.location_type
					})
		
		# Соединения между видимыми точками
		if node.location_type == "point" and node.visible:
			for connected_id in node.children_ids:
				if location_nodes.has(connected_id) and location_nodes[connected_id].visible:
					connections_to_draw.append({
						"start": node,
						"end": location_nodes[connected_id],
						"type": "point_connection"
					})
	
	# Теперь рисуем все собранные соединения
	for conn in connections_to_draw:
		create_connection_line(conn["start"], conn["end"], conn["type"])
		
	print("Отрисовано соединений:", connections_to_draw.size())

# Создание линии соединения
func create_connection_line(start_node, end_node, connection_type):
	var line = Line2D.new()
	line.add_point(start_node.position)
	line.add_point(end_node.position)
	
	# Определяем цвет линии в зависимости от типа соединения
	var color = Color(0.5, 0.5, 0.5)  # По умолчанию серый
	
	match connection_type:
		"expedition":
			color = Color(1.0, 0.8, 0.2)  # Желтый
		"stage":
			color = Color(0, 0.7, 1.0)  # Голубой
		"group":
			color = Color(0.8, 0.2, 0.8)  # Фиолетовый
		"point":
			color = Color(0.6, 0.6, 0.6)  # Светло-серый
		"point_connection":
			color = Color(0.4, 0.4, 0.4)  # Темно-серый
	
	# Активные соединения ярче
	if start_node.is_active or end_node.is_active:
		# Усиливаем яркость, но сохраняем оттенок
		color = color.lightened(0.3)
	
	line.default_color = color
	line.width = 2.0
	
	# Сохраняем метаданные для последующего выделения
	line.set_meta("start_id", start_node.location_id)
	line.set_meta("end_id", end_node.location_id)
	line.set_meta("type", connection_type)
	
	$Connections.add_child(line)
	return line

# Раскрытие локации (показ дочерних элементов)
# Исправленная функция expand_location в map.gd
# В map.gd, переделанная функция expand_location:
# map.gd - expand_location
func expand_location(location_id: String):
	if not location_nodes.has(location_id):
		return
		
	var node = location_nodes[location_id]
	node.is_expanded = true
	
	print("Разворачиваем локацию:", location_id, "тип:", node.location_type)
	
	# Показываем дочерние элементы
	for child_id in node.children_ids:
		if location_nodes.has(child_id):
			location_nodes[child_id].visible = true
			
			# Если это группа, разблокируем только первую точку
			if node.location_type == "group" and location_nodes[child_id].location_type == "point":
				if child_id == node.children_ids[0]:
					location_nodes[child_id].set_enabled()
					print("Разблокируем первую точку:", child_id)
				else:
					location_nodes[child_id].set_disabled()
			
			# Если это Stage, разблокируем только первую группу
			elif node.location_type == "stage" and location_nodes[child_id].location_type == "group":
				if child_id == node.children_ids[0]:
					location_nodes[child_id].set_enabled()
				else:
					location_nodes[child_id].set_disabled()
	
	# Перерисовываем соединения
	draw_connections()

# Загружаем сцену
func collapse_location(location_id: String):
	if not location_nodes.has(location_id):
		return
		
	var node = location_nodes[location_id]
	node.is_expanded = false
	
	print("Сворачиваем локацию:", location_id)
	
	# Скрываем все дочерние элементы
	for child_id in node.children_ids:
		if location_nodes.has(child_id):
			location_nodes[child_id].visible = false
			
			# Рекурсивно скрываем всех потомков
			var processed_nodes = [location_id]
			hide_all_children(child_id, processed_nodes)
			
	title_label.text = ""
	date_label.text = ""
	description_label.text = ""
	diary_label.text = ""
	
	# Перерисовываем соединения
	draw_connections()
	
# Новая функция для скрытия дочерних элементов без сброса состояния
func hide_children_without_state_reset(node_id: String, processed: Array = []):
	if not location_nodes.has(node_id) or processed.has(node_id):
		return
	
	processed.append(node_id)
	var node = location_nodes[node_id]
	
	for child_id in node.children_ids:
		if location_nodes.has(child_id):
			location_nodes[child_id].visible = false
			hide_children_without_state_reset(child_id, processed)

# Новая функция для скрытия всех дочерних элементов без анимации
# Fixed version to prevent infinite recursion
func hide_all_children(node_id: String, processed_nodes: Array = []):
	if not location_nodes.has(node_id) or processed_nodes.has(node_id):
		return
		
	# Mark this node as processed to prevent infinite recursion
	processed_nodes.append(node_id)
	
	var node = location_nodes[node_id]
	
	for child_id in node.children_ids:
		if location_nodes.has(child_id):
			location_nodes[child_id].visible = false
			location_nodes[child_id].is_expanded = false
			hide_all_children(child_id, processed_nodes)

# Вспомогательная функция для сбора всех дочерних элементов
func collect_all_children(parent_id: String, result_array: Array):
	if not location_nodes.has(parent_id):
		return
		
	var node = location_nodes[parent_id]
	
	for child_id in node.children_ids:
		if location_nodes.has(child_id) and not result_array.has(child_id):
			result_array.append(child_id)
			collect_all_children(child_id, result_array)

# Рекурсивное скрытие дочерних элементов
func hide_children_recursive(children_ids: Array, depth: int = 0):
	if depth > 5:  # Защита от бесконечной рекурсии
		print("Достигнут лимит рекурсии в hide_children_recursive")
		return
		
	for child_id in children_ids:
		if location_nodes.has(child_id):
			var child_node = location_nodes[child_id]
			
			# Анимируем исчезновение
			var tween = create_tween()
			tween.tween_property(child_node, "modulate:a", 0.0, 0.2)
			tween.finished.connect(func():
				child_node.visible = false
				
				# Сбрасываем состояние развернутости
				child_node.is_expanded = false
				
				# Если у этого ребенка есть дети, скрываем и их
				if child_node.has_children:
					hide_children_recursive(child_node.children_ids, depth + 1)
			)

# Перемещение к локации
func move_to_location(location_id: String):
	if not location_nodes.has(location_id):
		return

	if location_id == active_location_id:
		return

	last_location_id = active_location_id
	if active_location_id != "" and not visited_locations.has(active_location_id):
		visited_locations.append(active_location_id)

	set_active_location(location_id)
	move_camera_to_location(location_nodes[location_id].position)
	
	# Раскрываем соответствующую иерархию
	ensure_hierarchy_visible(location_id)
	
	# Обновляем интерфейс
	update_ui_with_location_data(location_id)

	if game_resources:
		game_resources.modify_resource("Energy", -10)
		
	var node = location_nodes[location_id]
	if node.location_type == "point" and node.parent_id != "":
		unlock_next_point(node.parent_id)

	update_visible_locations()	
	# Перерисовываем соединения после всех изменений
	draw_connections()

# Обеспечиваем видимость иерархии для данной локации
func ensure_hierarchy_visible(location_id: String, depth: int = 0):
	if depth > 5:
		print("Достигнут лимит рекурсии в ensure_hierarchy_visible")
		return
		
	if not location_nodes.has(location_id):
		return
		
	var node = location_nodes[location_id]
	
	# Всегда делаем видимой
	node.visible = true
	
	# Выводим отладочную информацию
	print("👁️ Делаем видимой точку:", location_id, "тип:", node.location_type)
	
	# Если это не корневой элемент, проверяем родителя
	if node.parent_id != "":
		if location_nodes.has(node.parent_id):
			var parent_node = location_nodes[node.parent_id]
			
			# Делаем родителя видимым
			parent_node.visible = true
			
			# Разворачиваем родителя, если он не развернут
			if not parent_node.is_expanded:
				parent_node.is_expanded = true
				expand_location(node.parent_id)
			
			# Делаем активным родителя соответствующего типа
			if parent_node.location_type == "group" and active_location_id != node.parent_id:
				set_active_location(node.parent_id)
			
			# Рекурсивно проверяем видимость родителя родителя
			ensure_hierarchy_visible(node.parent_id, depth + 1)
			
# Установка активной локации
# Улучшенная функция set_active_location
func set_active_location(location_id: String):
	if not location_nodes.has(location_id):
		return

	# Определяем тип локации
	var node_type = location_nodes[location_id].location_type
	
	# Деактивируем предыдущие активные точки того же типа
	for id in location_nodes.keys():
		var node = location_nodes[id]
		if node.location_type == node_type and node.is_active and id != location_id:
			node.set_active(false)

	# Устанавливаем новую активную локацию
	active_location_id = location_id
	location_nodes[location_id].set_active(true)
	
	# ВАЖНО: Экспедиция всегда активна
	if node_type != "expedition" and location_nodes.has("expedition"):
		location_nodes["expedition"].set_active(true)
	
	# Перерисовываем соединения для обновления цветов
	draw_connections()

# Обновление интерфейса данными о локации
# Исправленная функция update_ui_with_location_data в map.gd
func update_ui_with_location_data(location_id: String):
	if not info_panel_container:
		info_panel_container = initialize_info_panel()
		
	for child in info_panel_container.get_children():
		child.queue_free()
		
	
	if not location_nodes.has(location_id):
		return
		
	var node = location_nodes[location_id]
	
	info_panel_container.visible = (node.location_type == "point")
	
	
	
	# Обновляем заголовок для всех типов
	
	
	# Описание и дневник обновляем только для Point
	if node.location_type == "point":
		title_label.text = node.title_en
		description_label.text = node.description_en
		
		# Обновляем дневник, если есть
		if diary_label and node.diary != "":
			diary_label.text = node.diary_en
			diary_label.visible = true
		elif diary_label:
			diary_label.visible = false
			
		# Для точек используем их конкретную дату
		if node.date_range != "":
			date_label.text = node.date_range
			print("Дата из точки:", node.date_range)
	
	
# Новая функция для обновления даты
# В map.gd в методе update_date_from_node:
func update_date_from_node(node):
	if not date_label:
		return
		
	var date_text = ""
	
	# Исправить проверку для точки:
	if node.location_type == "point":
		# Точка может использовать date_range вместо date
		if node.date_range != "":
			date_text = node.date_range
			current_date = node.date_range
			print("Установлена дата из точки:", date_text)
	
	# Устанавливаем текст даты
	if date_text != "":
		date_label.text = date_text

# Перемещение камеры к локации
func move_camera_to_location(target_pos):
	if camera.has_meta("current_tween"):
		var old_tween = camera.get_meta("current_tween")
		if is_instance_valid(old_tween) and old_tween.is_valid():
			old_tween.kill()
		
	var tween = create_tween()
	camera.set_meta("current_tween", tween)
	
	tween.tween_property(camera, "position", target_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# Обновление видимых локаций
# В функции update_visible_locations нужно изменить:
func update_visible_locations():
	# Блокируем точки, которые не доступны по дате
	for loc_id in location_nodes.keys():
		var node = location_nodes[loc_id]
		
		# Проверяем дату для точек
		if node.location_type == "point":
			if is_date_passed(node.date_range, current_date):
				# Если дата прошла, разблокируем точку
				node.set_enabled()
			else:
				# Иначе блокируем
				node.set_disabled()
	
	# Блокируем ТОЛЬКО посещенные точки, но не все подряд
	for prev_id in visited_locations:
		if location_nodes.has(prev_id) and prev_id != active_location_id:
			location_nodes[prev_id].set_disabled()

# Создание карточки события
# Создание карточки события
# Замените функцию create_event_card в map.gd на эту:

# Обновленная функция create_event_card для улучшенного дизайна

func create_event_card(card: Dictionary):
	if not event_card_scene:
		print("Ошибка: Префаб карточки событий не назначен!")
		return

	var event_card_instance = event_card_scene.instantiate()
	
	# Строго фиксированный размер всех карточек
	event_card_instance.custom_minimum_size = Vector2(250, 300)
	event_card_instance.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	var vbox = event_card_instance.get_node_or_null("VBoxContainer")
	if vbox:
		# Фиксированная высота VBoxContainer
		vbox.custom_minimum_size.y = 280
		vbox.size_flags_vertical = Control.SIZE_FILL
		
		# Отступы внутри карточки
		vbox.add_theme_constant_override("margin_left", 10)
		vbox.add_theme_constant_override("margin_right", 10)
		vbox.add_theme_constant_override("margin_top", 10)
		vbox.add_theme_constant_override("margin_bottom", 10)
	
	var title_node = event_card_instance.get_node_or_null("VBoxContainer/Title")
	var description_node = event_card_instance.get_node_or_null("VBoxContainer/Description")
	
	if not title_node or not description_node:
		print("❌ Ошибка: Проблема с нодами внутри карточки!")
		return

	# Стилизация заголовка
	title_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_node.add_theme_font_size_override("font_size", 16)
	title_node.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	title_node.custom_minimum_size.y = 40
	title_node.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	# Добавляем разделительную линию
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 10)
	vbox.add_child(separator)
	vbox.move_child(separator, 1) # После заголовка
	
	# Настройка описания с автопереносом и фиксированной высотой
	description_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_node.custom_minimum_size.y = 60
	description_node.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	description_node.add_theme_constant_override("line_spacing", 3)
	
	# Создаем контейнер для эффектов с фиксированной высотой
	var effects_container = VBoxContainer.new()
	effects_container.custom_minimum_size.y = 100
	effects_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_child(effects_container)
	vbox.move_child(effects_container, 2) # После разделителя
	
	# Отображение эффектов действия на ресурсы
	var boost = card.get("boost", {})
	if not boost.is_empty():
		var effects_title = Label.new()
		effects_title.text = "Effects:"
		effects_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effects_title.add_theme_font_size_override("font_size", 14)
		effects_container.add_child(effects_title)
		
		var grid = GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 10)
		effects_container.add_child(grid)
		
		for resource_name in boost:
			var resource_key = resource_name
			match resource_name.to_lower():
				"food": resource_key = "Food"
				"energy": resource_key = "Energy" 
				"warmth": resource_key = "Temperature"
				"morale": resource_key = "Morale"
				
			var amount = boost[resource_name]
			
			var res_label = Label.new()
			res_label.text = resource_key + ":"
			res_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			res_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			
			var val_label = Label.new()
			val_label.text = ("+" if amount > 0 else "") + str(amount)
			val_label.size_flags_horizontal = Control.SIZE_FILL
			val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			
			# Цветовая индикация положительных/отрицательных эффектов
			if amount > 0:
				val_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
			elif amount < 0:
				val_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			
			grid.add_child(res_label)
			grid.add_child(val_label)
	else:
		# Если эффектов нет, добавляем пустое пространство для сохранения высоты
		var empty_label = Label.new()
		empty_label.text = "No effects"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effects_container.add_child(empty_label)
	
	# Добавляем информацию об очках внизу
	var footer = VBoxContainer.new()
	footer.custom_minimum_size.y = 40
	footer.size_flags_vertical = Control.SIZE_SHRINK_END
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(footer)
	
	var points = card.get("points", 0)
	if points > 0:
		var points_label = Label.new()
		points_label.text = "Value: " + str(points) + " points"
		points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		points_label.add_theme_font_size_override("font_size", 12)
		points_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		footer.add_child(points_label)
	
	# Создаем новую кнопку
	var new_apply_button = Button.new()
	new_apply_button.text = "Apply"
	new_apply_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	footer.add_child(new_apply_button)
	
	# Устанавливаем стиль фона для карточки
	var panel = event_card_instance
	panel.add_theme_stylebox_override("panel", create_card_style())
	
	# Используем правильные поля из card
	title_node.text = card.get("title_en", card.get("title", "Unknown Event"))
	description_node.text = card.get("description_en", card.get("description", "No description available."))

	# Подключаем сигнал к новой кнопке
	new_apply_button.pressed.connect(func():
		# Создаем эффект на ресурсы из boost
		for resource_name in boost:
			update_resource(resource_name, boost[resource_name])
		
		print("Применен эффект карточки:", card.get("title_en", ""), "очки:", points)
		AudioManager.play_sound("card_play")
		
		# Удаляем карточку через родительский MarginContainer
		var parent = event_card_instance.get_parent()
		if parent:
			parent.queue_free()
		else:
			event_card_instance.queue_free()
	)

	# Создаем горизонтальный контейнер, если его еще нет
	var hbox_container
	if not event_panel.has_node("HBoxContainer"):
		hbox_container = HBoxContainer.new()
		hbox_container.name = "HBoxContainer"
		hbox_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox_container.alignment = BoxContainer.ALIGNMENT_CENTER
		event_panel.add_child(hbox_container)
	else:
		hbox_container = event_panel.get_node("HBoxContainer")
	
	# Добавляем карточку в контейнер с отступами
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_child(event_card_instance)
	hbox_container.add_child(margin)
# Создание стиля для карточек
func create_card_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	
	# Фон
	style.bg_color = Color(0.15, 0.22, 0.22, 0.9)
	
	# Скругленные углы
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	
	# Граница
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_color = Color(0.3, 0.5, 0.5, 0.7)
	
	# Внутренний отступ
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	
	# Тень
	style.shadow_size = 3
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_offset = Vector2(2, 2)
	
	return style
	
	
func style_all_ui_elements():	
	# Стилизуем информацию справа
	style_expedition_info()
	
	# Стилизуем панель с карточками
	style_card_panel()



# Стиль для панели ресурсов
func create_resource_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	
	# Фон
	style.bg_color = Color(0.15, 0.22, 0.22, 0.8)
	
	# Скругленные углы
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	
	# Граница
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.3, 0.5, 0.5, 0.7)
	
	# Отступы
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_bottom = 5
	
	return style

# Стилизация информации о точке
func style_expedition_info():
	if not title_label or not description_label:
		return
		
	# Создаём стиль для панели с информацией
	var info_panel = title_label.get_parent()
	if info_panel:
		var style = create_card_style()
		style.bg_color = Color(0.12, 0.18, 0.20, 0.85)
		
		# Добавляем стилизованную панель
		var panel_bg = PanelContainer.new()
		panel_bg.add_theme_stylebox_override("panel", style)
		
		# Перемещаем содержимое
		var parent = info_panel.get_parent()
		var idx = info_panel.get_index()
		
		parent.remove_child(info_panel)
		panel_bg.add_child(info_panel)
		parent.add_child(panel_bg)
		parent.move_child(panel_bg, idx)
	
	# Стилизуем заголовок
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	
	# Добавляем разделитель под заголовком
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 10)
	separator.add_theme_color_override("color", Color(0.6, 0.7, 0.8, 0.5))
	title_label.get_parent().add_child(separator)
	title_label.get_parent().move_child(separator, title_label.get_index() + 1)
	
	# Стилизуем дату
	if date_label:
		date_label.add_theme_font_size_override("font_size", 14)
		date_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		
	# Стилизуем описание
	description_label.add_theme_font_size_override("font_size", 14)
	description_label.add_theme_constant_override("line_spacing", 5)
	
	# Стилизуем дневник
	# Стилизуем дневник только если он существует и в нем есть текст
	if diary_label and diary_label.visible:
		# Проверяем существование текста перед обработкой
		if diary_label.text != null and diary_label.text.strip_edges() != "":
			# Ищем существующий контейнер для дневника
			var existing_container = diary_label.get_parent()
			if existing_container is PanelContainer and existing_container.name == "DiaryContainer":
				# Контейнер уже создан, не создаем снова
				existing_container.visible = true
			else:
				# Создаем новый контейнер
				var diary_container = PanelContainer.new()
				diary_container.name = "DiaryContainer"
				var style = StyleBoxFlat.new()
				style.bg_color = Color(0.1, 0.12, 0.15, 0.7)
				style.border_width_top = 1
				style.border_width_right = 1
				style.border_width_bottom = 1
				style.border_width_left = 1
				style.border_color = Color(0.4, 0.5, 0.6, 0.5)
				style.corner_radius_top_left = 5
				style.corner_radius_top_right = 5
				style.corner_radius_bottom_left = 5
				style.corner_radius_bottom_right = 5
				style.content_margin_left = 10
				style.content_margin_right = 10
				style.content_margin_top = 10
				style.content_margin_bottom = 10
				
				diary_container.add_theme_stylebox_override("panel", style)
				
				# Перемещаем дневник в новый контейнер
				var parent = diary_label.get_parent()
				var idx = diary_label.get_index()
				parent.remove_child(diary_label)
				diary_container.add_child(diary_label)
				parent.add_child(diary_container)
				parent.move_child(diary_container, idx)
				
				# Добавляем заголовок для дневника
				
				# Стилизуем текст дневника
				diary_label.add_theme_font_size_override("font_size", 13)
				diary_label.add_theme_constant_override("line_spacing", 4)
				diary_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
				
				# Пробуем загрузить шрифт
				var font = load("res://fonts/Kalam-Regular.ttf")
				if font:
					diary_label.add_theme_font_override("font", font)
		else:
			# Если дневник пуст, скрываем существующий контейнер
			var diary_container = diary_label.get_parent()
			if diary_container is PanelContainer and diary_container.name == "DiaryContainer":
				diary_container.visible = false

# Стилизация панели карточек
# 3. "Available Actions" должен показываться только при клике на Point
# В методе style_card_panel добавим проверку:

func style_card_panel():
	if not event_panel:
		return
		
	# Добавляем фон для панели карточек
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.18, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	
	# Убираем зеленую рамку, используем более нейтральный цвет
	style.border_color = Color(0.3, 0.4, 0.5, 0.5)
	
	event_panel.add_theme_stylebox_override("panel", style)
	
	# Добавляем заголовок для карточек, но ТОЛЬКО если активная точка - тип Point
	var card_title = event_panel.get_node_or_null("CardTitle")
	
	# Удаляем существующий заголовок, если есть
	if card_title:
		card_title.queue_free()
	
	# Проверяем тип активной локации
	if location_nodes.has(active_location_id) and location_nodes[active_location_id].location_type == "point":
		var label = Label.new()
		label.name = "CardTitle"
		label.text = "Available Actions"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		
		event_panel.add_child(label)
		
		# Если есть HBoxContainer, добавляем заголовок перед ним
		var hbox = event_panel.get_node_or_null("HBoxContainer")
		if hbox:
			event_panel.move_child(label, hbox.get_index())
	
	# Также скрываем панель, если нет активной точки типа point
	event_panel.visible = location_nodes.has(active_location_id) and location_nodes[active_location_id].location_type == "point"
	
	
# Обновите функцию load_event_cards, чтобы очищать HBoxContainer
func load_event_cards(location_id: String):
	# Удаляем старые карточки
	var hbox = event_panel.get_node_or_null("HBoxContainer")
	if hbox:
		for child in hbox.get_children():
			child.queue_free()
	else:
		# Удаляем прямые дочерние элементы, если HBoxContainer еще не создан
		for child in event_panel.get_children():
			child.queue_free()

# Применение эффекта события
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

# Обновление ресурса
func update_resource(resource_name: String, amount: int):
	# Маппинг имен ресурсов из карточек к именам в системе
	var resource_key = resource_name
	match resource_name.to_lower():
		"food": resource_key = "Food"
		"energy": resource_key = "Energy" 
		"warmth": resource_key = "Temperature"
		"morale": resource_key = "Morale"
	
	# Обновляем локальный кэш ресурсов
	if resources.has(resource_key):
		resources[resource_key] += amount
		
		# Обновляем глобальный менеджер ресурсов
		if game_resources and game_resources.resources.has(resource_key):
			game_resources.modify_resource(resource_key, amount)
			
			# Воспроизводим звук в зависимости от увеличения/уменьшения ресурса
			if amount > 0:
				AudioManager.play_sound("resource_gain")
			elif amount < 0:
				AudioManager.play_sound("resource_loss")
				
			print(resource_key, " изменено на ", amount, ", новое значение: ", 
				  game_resources.resources[resource_key].amount)

# Установка текущей даты
func set_current_date(new_date):
	current_date = new_date

# Проверка прохождения даты
func is_date_passed(date1, date2) -> bool:
	return parse_date(date1) <= parse_date(date2)

# Парсинг даты в сравнимый формат
func parse_date(date_str: String) -> int:
	var parts = date_str.split(".")
	if parts.size() == 3:
		return int(parts[2]) * 10000 + int(parts[1]) * 100 + int(parts[0])
	return 0  # Если формат неправильный

# Обработка ввода для камеры и управления
func _unhandled_input(event):
	# Масштабирование камеры
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_camera(1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_camera(0.9)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Возвращение камеры к активной точке
			if active_location_id != "" and location_nodes.has(active_location_id):
				move_camera_to_location(location_nodes[active_location_id].position)
			
	# Управление камерой с клавиатуры
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
			KEY_ESCAPE:
				get_tree().paused = true
				var GameMenuScene = preload("res://scenes/ingame_menu.tscn").instantiate()
				add_child(GameMenuScene)


# Функция для масштабирования камеры
func zoom_camera(factor):
	var new_zoom = camera.zoom * factor
	# Ограничиваем масштаб
	new_zoom = new_zoom.clamp(Vector2(0.5, 0.5), Vector2(2, 2))
	
	var tween = create_tween()
	tween.tween_property(camera, "zoom", new_zoom, 0.1)

# Создание необходимых сцен для точек, если они отсутствуют
func ensure_point_scenes_exist():
	# Проверяем наличие сцен в проекте
	var scenes_to_check = {
		"ExpeditionPoint": "res://scenes/ExpeditionPoint.tscn",
		"StagePoint": "res://scenes/StagePoint.tscn",
		"GroupPoint": "res://scenes/GroupPoint.tscn",
		"PointLocation": "res://scenes/PointLocation.tscn"
	}
	
	var scene_exists = true
	
	for scene_name in scenes_to_check:
		if not FileAccess.file_exists(scenes_to_check[scene_name]):
			print("❌ Сцена не найдена:", scenes_to_check[scene_name])
			scene_exists = false
	
	if not scene_exists:
		print("⚠️ Необходимо создать недостающие сцены точек!")
		# Здесь можно добавить код для создания сцен программно
		
# Добавьте новую функцию
func unlock_next_point(group_id: String):
	if not location_nodes.has(group_id):
		return
		
	var group_node = location_nodes[group_id]
	
	# Если это не группа - выход
	if group_node.location_type != "group":
		return
	
	var unlocked_any = false
	
	# Разблокируем первую непосещенную точку в группе
	for child_id in group_node.children_ids:
		if location_nodes.has(child_id) and not child_id in visited_locations:
			# Нашли непосещенную точку
			location_nodes[child_id].set_enabled()
			print("✅ Разблокирована точка:", child_id)
			unlocked_any = true
			break
	
	# Если все точки в группе посещены, разблокируем следующую группу
	if not unlocked_any and group_node.parent_id != "":
		var parent_node = location_nodes[group_node.parent_id]
		
		# Проверяем, все ли дети в этой группе посещены
		var all_visited = true
		for sibling_id in parent_node.children_ids:
			if location_nodes.has(sibling_id) and location_nodes[sibling_id].location_type == "group":
				# Проверяем точки внутри этой группы
				for point_id in location_nodes[sibling_id].children_ids:
					if not point_id in visited_locations:
						all_visited = false
						break
		
		# Если все посещены, ищем следующую неразблокированную группу
		if all_visited:
			# Получаем индекс текущей группы
			var group_index = parent_node.children_ids.find(group_id)
			
			# Если есть следующая группа, разблокируем ее
			if group_index < parent_node.children_ids.size() - 1:
				var next_group_id = parent_node.children_ids[group_index + 1]
				if location_nodes.has(next_group_id):
					location_nodes[next_group_id].set_enabled()
					unlock_next_point(next_group_id)
					
func initialize_info_panel():
	# Удаляем существующую панель, если она есть
	if info_panel_container:
		info_panel_container.queue_free()
		
	# Создаем новую панель
	info_panel_container = PanelContainer.new()
	info_panel_container.name = "InfoPanel"
	info_panel_container.visible = false
	
	# Настраиваем стиль
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.22, 0.22, 0.85)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.3, 0.5, 0.5, 0.7)
	info_panel_container.add_theme_stylebox_override("panel", style)
	
	# Добавляем в сцену
	var canvas_layer = $CanvasLayer
	canvas_layer.add_child(info_panel_container)
	
	# Возвращаем контейнер для дальнейшей настройки
	return info_panel_container
					
					
func print_debug_info():
	print("=== Отладочная информация ===")
	print("Всего точек: ", location_nodes.size())
	
	var types = {"expedition": 0, "stage": 0, "group": 0, "point": 0}
	var visible = {"expedition": 0, "stage": 0, "group": 0, "point": 0}
	
	for loc_id in location_nodes.keys():
		var node = location_nodes[loc_id]
		types[node.location_type] += 1
		
		if node.visible:
			visible[node.location_type] += 1
	
	print("По типам:")
	for type in types.keys():
		print("- ", type, ": ", types[type], " (видимо: ", visible[type], ")")
	
	print("Активная локация: ", active_location_id)
	print("=========================")
