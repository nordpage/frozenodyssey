extends Control


func _ready():
	$"Menu/Buttons/ResumeButton".pressed.connect(_on_ResumeButton_pressed)
	$"Menu/Buttons/ExitButton".pressed.connect(_on_ExitButton_pressed)
	process_mode = Node.ProcessMode.PROCESS_MODE_ALWAYS

func _on_ResumeButton_pressed():
	# Возобновляем игру
	get_tree().paused = false
	# Закрываем меню (удаляем его из дерева сцены)
	queue_free()
	

func _on_ExitButton_pressed():
	# Возобновляем игру
	get_tree().paused = false
	# Закрываем меню (удаляем его из дерева сцены)
	queue_free()
