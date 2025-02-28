extends Control

@onready var progress_bar = $VBoxContainer/Progress
@onready var label = $VBoxContainer/Label

func _ready():
	show_loading()
	# Запускаем загрузку сцены
	SceneLoader.load_scene()

func show_loading():
	show()
	label.text = "Loading..."
	progress_bar.value = 0

func set_progress(value):
	progress_bar.value = value

func show_error():
	print("Ошибка загрузки!")
