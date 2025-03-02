# HUD.gd
extends Control

# Ссылки на UI элементы - обновим пути с учетом новой структуры
@onready var temperature_label = $HUDContainer/TempContainer/TemperatureValue
@onready var food_label = $HUDContainer/FoodContainer/FoodValue
@onready var energy_label = $HUDContainer/EnergyContainer/EnergyValue
@onready var morale_label = $HUDContainer/MoraleContainer/MoraleValue
@onready var turn_label = $HUDContainer/TurnContainer/TurnValue

# Теперь получаем ссылку на GameResources через Map
@onready var map = get_node("/root/Main/Map")
@onready var game_resources = get_node("/root/Main/GameResources")

var current_turn = 1
var current_date = "08.12.1912"  # Обновим начальную дату в соответствии с экспедицией

func _ready():
	# Начальная настройка
	update_hud()
	
	# Применяем стилизацию
	style_hud()

func _process(_delta):
	# Регулярное обновление значений
	update_hud()

func update_hud():
	if not game_resources:
		return
		
	# Обновляем значения ресурсов
	update_resource_label(temperature_label, "Temperature")
	update_resource_label(food_label, "Food")
	update_resource_label(energy_label, "Energy")
	update_resource_label(morale_label, "Morale")
	
	# Обновляем ход и дату
	if turn_label:
		turn_label.text = str(current_turn)
		
	# Синхронизируем дату с Map
	if map:
		current_date = map.current_date

func update_resource_label(label, resource_name):
	if not label or not game_resources:
		return
		
	var resource = game_resources.get_resource(resource_name)
	if resource:
		# Обновляем текст
		label.text = str(resource.amount) + "/" + str(resource.max_amount)
		
		# Меняем цвет в зависимости от значения
		if resource.amount < resource.max_amount * 0.2:
			# Критический уровень (менее 20%)
			label.add_theme_color_override("font_color", Color(1, 0, 0))
		elif resource.amount < resource.max_amount * 0.5:
			# Низкий уровень (менее 50%)
			label.add_theme_color_override("font_color", Color(1, 0.5, 0))
		else:
			# Нормальный уровень
			label.add_theme_color_override("font_color", Color(1, 1, 1))

# Анимация мигания ресурса при изменении
func flash_resource_label(label):
	if not label:
		return
		
	var original_modulate = label.get_modulate()
	
	var tween = create_tween()
	tween.tween_property(label, "modulate", Color(1, 1, 0, 1), 0.1)  # Желтый
	tween.tween_property(label, "modulate", original_modulate, 0.1)  # Возврат к исходному

func increment_turn():
	current_turn += 1
	
	# Обновляем дату при необходимости
	# Например, каждый ход может соответствовать определенному периоду времени

# Стилизация HUD
func style_hud():
	# Создаем фоновую панель для HUD
	var hud_container = $HUDContainer
	if not hud_container:
		return
		
	var panel_bg = PanelContainer.new()
	panel_bg.name = "HUDPanel"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.22, 0.22, 0.9)
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.3, 0.5, 0.5, 0.7)
	panel_bg.add_theme_stylebox_override("panel", style)
	
	# Перемещаем HUDContainer в панель
	move_child(hud_container, -1)  # Перемещаем в начало списка
	remove_child(hud_container)
	panel_bg.add_child(hud_container)
	add_child(panel_bg)
	
	# Стилизуем метки ресурсов
	for container_name in ["TempContainer", "FoodContainer", "EnergyContainer", "MoraleContainer", "TurnContainer"]:
		var container = hud_container.get_node_or_null(container_name)
		if container:
			var label_name = container_name.replace("Container", "Value")
			var label = container.get_node_or_null(label_name)
			if label:
				label.add_theme_font_size_override("font_size", 16)
				label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
