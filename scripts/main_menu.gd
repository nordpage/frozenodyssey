# MainMenu.gd
extends Control

func _ready():
	$VBoxContainer/MenuButtons/NewGameButton.pressed.connect(_on_new_game_pressed)
	$VBoxContainer/MenuButtons/ContinueButton.pressed.connect(_on_continue_pressed)
	$VBoxContainer/MenuButtons/ExitButton.pressed.connect(_on_exit_pressed)
	
	# Проверка наличия сохранения
	$VBoxContainer/MenuButtons/ContinueButton.disabled = !FileAccess.file_exists(SaveManager.SAVE_PATH)

func _on_new_game_pressed():
	#get_tree().change_scene_to_file("res://main.tscn")
	AudioManager.play_sound("click")
	SceneLoader.start_loading("res://main.tscn", self, "on_new_game_loaded")


func _on_continue_pressed():
	AudioManager.play_sound("click")
	
	# Сохраняем ссылку на MainMenu
	var menu = self
	
	# Вызываем загрузку с callback
	SceneLoader.start_loading("res://main.tscn", menu, "on_scene_loaded")

# Будет вызвано после загрузки сцены
func on_scene_loaded():
	var map_node = get_node_or_null("/root/Main/Map")
	if map_node:
		map_node.load_game()
		
func on_new_game_loaded():
	var map_node = get_node_or_null("/root/Main/Map")
	if map_node:
		# Сбрасываем сохранение (если нужно)
		map_node.reset_game()
		
		# Показываем туториал
		var tutorial = load("res://scenes/tutorial.tscn").instantiate()
		get_node("/root").add_child(tutorial)

func _on_exit_pressed():
	get_tree().quit()
	AudioManager.play_sound("click")
