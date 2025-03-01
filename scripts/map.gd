extends Node2D

@export var title_label: Label
@export var description_label: Label
@export var diary_label: Label
@onready var date_label = $"../CanvasLayer/Control/HUDContainer/DateContainer/DateValue"
@export var event_panel: PanelContainer
@export var event_card_scene: PackedScene
@export var camera_speed: float = 500.0

@onready var event_manager = get_node_or_null("/root/Main/EventManager")
@onready var game_resources = get_node_or_null("/root/Main/GameResources")
@onready var camera = $Camera2D

var expedition_data = {}
var location_nodes = {}
var active_location_id: String = ""
var visited_locations = []
var last_location_id = ""
var original_positions = {}
var current_date = "08.12.1912"
var camera_move = Vector2.ZERO

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
	
	# Применяем логику отображения как в Total War:
	# 1. Все экспедиции видны
	# 2. Только первая экспедиция активна
	# 3. Этапы скрыты до клика
	# 4. Группы скрыты до клика
	# 5. Точки скрыты до клика
	set_total_war_visibility()
	
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
	
	
func set_total_war_visibility():
	# Проходим по всем нодам и устанавливаем видимость
	for loc_id in location_nodes.keys():
		var node = location_nodes[loc_id]
		
		match node.location_type:
			"expedition":
				# Экспедиция всегда видна и активна
				node.visible = true
				node.set_active(true)
				# Сразу разворачиваем для показа этапов
				node.is_expanded = true
				
			"stage":
				# Все этапы видны
				node.visible = true
				
				# Только первый этап активен, остальные заблокированы
				var first_stage_id = ""
				if expedition_data.has("levels") and expedition_data["levels"].size() > 0:
					first_stage_id = expedition_data["levels"][0]["id"]
				
				if loc_id == first_stage_id:
					node.set_enabled()
					# Разворачиваем первый этап для показа первой группы
					node.is_expanded = true
				else:
					node.set_disabled()
					
			"group":
				# Группы видны только для активного этапа
				var parent_node = null
				if node.parent_id != "" and location_nodes.has(node.parent_id):
					parent_node = location_nodes[node.parent_id]
				
				if parent_node and parent_node.is_expanded:
					node.visible = true
					
					# Только первая группа активна
					var first_group_id = ""
					if parent_node.children_ids.size() > 0:
						first_group_id = parent_node.children_ids[0]
					
					if loc_id == first_group_id:
						node.set_enabled()
					else:
						node.set_disabled()
				else:
					node.visible = false
					
			"point":
				# Точки скрыты изначально за исключением первой точки в первой группе
				node.visible = false
				
				# Проверяем, это первая точка в группе?
				var parent_node = null
				if node.parent_id != "" and location_nodes.has(node.parent_id):
					parent_node = location_nodes[node.parent_id]
				
				if parent_node and parent_node.children_ids.size() > 0 and parent_node.children_ids[0] == loc_id:
					# Это первая точка в группе
					if parent_node.is_expanded:
						node.visible = true
						node.set_enabled()
					else:
						node.set_disabled()
				else:
					node.set_disabled()
	
	# Отображаем первую точку в первой группе первого этапа
	if expedition_data.has("levels") and expedition_data["levels"].size() > 0:
		var first_stage = expedition_data["levels"][0]
		if first_stage.has("children") and first_stage["children"].size() > 0:
			var first_group = first_stage["children"][0]
			if first_group.has("children") and first_group["children"].size() > 0:
				var first_point_id = first_group["children"][0]["id"]
				if location_nodes.has(first_point_id):
					# Разблокируем и показываем первую точку
					location_nodes[first_point_id].set_enabled()
					
					# Если группа развернута, делаем точку видимой
					if location_nodes.has(first_group["id"]) and location_nodes[first_group["id"]].is_expanded:
						location_nodes[first_point_id].visible = true

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
		point_node.description = point.get("description", "")
		point_node.date_range = point.get("date", "")
		point_node.parent_id = parent_id
		
		# Явно устанавливаем интерактивность для точек
		point_node.input_pickable = true
		point_node.set_process_input(true)
		
		# Дневниковая запись
		if point.has("diary"):
			point_node.diary = point["diary"]
		
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
func _on_location_selected(location_id: String):
	# Обработка клика на локацию
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
	
	# Если выбрана точка, добавляем её в посещенные
	if selected_node.location_type == "point" and not visited_locations.has(location_id):
		visited_locations.append(location_id)
		# Разблокируем следующую точку в группе
		unlock_next_point_in_group(selected_node.parent_id)
	
	# Перемещаем камеру к выбранной локации
	move_camera_to_location(selected_node.position)
	
	# Разворачиваем выбранную локацию, если у неё есть дочерние элементы
	if selected_node.has_children and not selected_node.is_expanded:
		selected_node.is_expanded = true
		expand_location(location_id)
	
	# Обеспечиваем видимость выбранной локации и её родителей
	ensure_hierarchy_visible(location_id)
	
	# Обновляем интерфейс
	update_ui_with_location_data(location_id)
	
	# Обновляем видимость локаций
	update_visible_locations()
	
	# Загружаем карточки событий
	load_event_cards(location_id)
	
	# Перерисовываем соединения
	draw_connections()
	
func unlock_next_point_in_group(group_id: String):
	if not location_nodes.has(group_id):
		return
		
	var group_node = location_nodes[group_id]
	if group_node.location_type != "group":
		return
	
	var points_in_group = []
	
	# Собираем все точки в группе
	for child_id in group_node.children_ids:
		if location_nodes.has(child_id) and location_nodes[child_id].location_type == "point":
			points_in_group.append(child_id)
	
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
	
	# Если все точки в группе посещены - разблокируем следующую группу
	elif last_visited_index == points_in_group.size() - 1:
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
	expand_location(location_id)

func _on_location_collapse(location_id: String):
	print("Сворачивание локации:", location_id)
	collapse_location(location_id)

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
func expand_location(location_id: String):
	if not location_nodes.has(location_id):
		return
		
	var node = location_nodes[location_id]
	node.is_expanded = true
	
	print("Разворачиваем локацию:", location_id, "тип:", node.location_type)
	
	# Показываем все дочерние элементы
	for child_id in node.children_ids:
		if location_nodes.has(child_id):
			# Сразу делаем видимым дочерний элемент
			location_nodes[child_id].visible = true
			print("Показываем дочерний элемент:", child_id)
			
			# Установим непрозрачность обратно на 1
			location_nodes[child_id].modulate.a = 1.0
			
			# Если это Group, и мы хотим сразу показать его дочерние Points
			if node.location_type == "stage" and location_nodes[child_id].location_type == "group":
				# Автоматически разворачиваем первую группу, если она еще не развернута
				if child_id == node.children_ids[0] and not location_nodes[child_id].is_expanded:
					location_nodes[child_id].is_expanded = true
					expand_location(child_id)
	
	# Перерисовываем соединения
	draw_connections()

# Сворачивание локации (скрытие дочерних элементов)
# Исправленная функция collapse_location в map.gd
# Исправленная версия collapse_location в map.gd
func collapse_location(location_id: String):
	if not location_nodes.has(location_id):
		return
		
	var node = location_nodes[location_id]
	
	print("Сворачиваем локацию:", location_id)
	node.is_expanded = false  # Явно устанавливаем флаг сворачивания
	
	# Скрываем все дочерние элементы сразу, без анимации
	for child_id in node.children_ids:
		if location_nodes.has(child_id):
			location_nodes[child_id].visible = false
			
			# Также сворачиваем все дочерние элементы, чтобы при следующем разворачивании не было проблем
			location_nodes[child_id].is_expanded = false
			
			# Рекурсивно скрываем дочерние элементы дочерних элементов
			hide_all_children(child_id)
	
	# Перерисовываем соединения ПОСЛЕ скрытия всех точек
	draw_connections()

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
	load_event_cards(location_id)
	
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
	if not location_nodes.has(location_id):
		return
		
	var node = location_nodes[location_id]
	
	# Обновляем заголовок для всех типов
	title_label.text = node.title
	
	# Описание и дневник обновляем только для Point
	if node.location_type == "point":
		description_label.text = node.description
		
		# Обновляем дневник, если есть
		if diary_label and node.diary != "":
			diary_label.text = node.diary
			diary_label.visible = true
		elif diary_label:
			diary_label.visible = false
	else:
		# Для других типов - скрываем или обнуляем информацию
		description_label.text = ""
		if diary_label:
			diary_label.visible = false
	
	# Обновляем дату
	update_date_from_node(node)
	
	
# Новая функция для обновления даты
func update_date_from_node(node):
	if not date_label:
		return
		
	var date_text = ""
	
	# Получаем дату в зависимости от типа
	if node.location_type == "point" and node.date_range != "":
		date_text = node.date_range
		current_date = node.date_range
	elif node.location_type == "group" and node.date_range != "":
		date_text = node.date_range
		# Берем первую часть диапазона
		current_date = node.date_range.split(" – ")[0] if " – " in node.date_range else node.date_range
	elif node.location_type == "stage" and node.date_range != "":
		date_text = node.date_range
		current_date = node.date_range.split(" – ")[0] if " – " in node.date_range else node.date_range
	
	# Устанавливаем текст даты, если он был найден
	if date_text != "":
		date_label.text = date_text
	else:
		# Иначе используем текущую дату
		date_label.text = current_date
		
	print("Обновлена дата:", date_label.text)

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
func update_visible_locations():
	# Блокируем точки, которые не доступны по дате
	for loc_id in location_nodes.keys():
		var node = location_nodes[loc_id]
		
		# Проверяем дату для точек
		if node.location_type == "point" and node.date_range != "":
			if is_date_passed(node.date_range, current_date):
				# Если дата прошла, разблокируем точку
				node.set_enabled()
			else:
				# Иначе блокируем
				node.set_disabled()
	
	# Блокируем все посещенные локации
	for prev_id in visited_locations:
		if location_nodes.has(prev_id) and prev_id != active_location_id:
			location_nodes[prev_id].set_disabled()

# Загрузка карточек событий
func load_event_cards(location_id: String):
	# Удаляем старые карточки
	for child in event_panel.get_children():
		child.queue_free()

	# Загружаем карточки событий для данной локации
	if event_manager:
		var cards = event_manager.get_location_cards(location_id)
		if cards.size() > 0:
			for card in cards:
				create_event_card(card)

# Создание карточки события
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
func update_resource(resource: String, amount: int):
	if resources.has(resource):
		resources[resource] += amount
		print(resource, "изменено на", amount, "текущее значение:", resources[resource])
		
		if game_resources:
			game_resources.modify_resource(resource, amount)

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
				if event.pressed and active_location_id != "":
					var node = location_nodes[active_location_id]
					if node.is_expanded:
						node.is_expanded = false
						collapse_location(active_location_id)
					elif node.parent_id != "":
						# Переходим к родителю, если есть
						move_to_location(node.parent_id)

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
