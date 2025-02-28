# HUD.gd
extends Control

# Ссылки на UI элементы
@onready var temperature_label = $HBoxContainer/TempContainer/TemperatureValue
@onready var food_label = $HBoxContainer/FoodContainer/FoodValue
@onready var energy_label = $HBoxContainer/EnergyContainer/EnergyValue
@onready var morale_label = $HBoxContainer/MoraleContainer/MoraleValue
@onready var turn_label = $HBoxContainer/TurnContainer/TurnValue
@onready var date_label = $HBoxContainer/DateContainer/DateValue

# Ссылка на GameResources
@onready var game_resources = get_node_or_null("/root/Main/GameResources")

var current_turn = 1
var current_date = "27.08.1912"  # Начальная дата экспедиции

func _ready():
	# Начальная настройка
	update_hud()

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
	turn_label.text = str(current_turn)
	date_label.text = current_date

func update_resource_label(label, resource_name):
	var resource = game_resources.get_resource(resource_name)
	if resource:
		label.text = str(resource.amount) + "/" + str(resource.max_amount)

func increment_turn():
	current_turn += 1
	# Можно добавить логику обновления даты здесь
