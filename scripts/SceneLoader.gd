extends Node

signal scene_loaded

var scene_path = ""
var callback_object = null
var callback_method = ""

func start_loading(path, cb_object = null, cb_method = ""):
	scene_path = path
	callback_object = cb_object
	callback_method = cb_method

	# Меняем сцену на LoadingScreen
	get_tree().change_scene_to_file("res://scenes/LoadingScreen.tscn")

func load_scene():
	if scene_path == "":
		return

	ResourceLoader.load_threaded_request(scene_path)
	set_process(true)

func _process(_delta):
	if scene_path == "":
		return

	var progress_array = []
	var status = ResourceLoader.load_threaded_get_status(scene_path, progress_array)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if progress_array.size() > 0:
				# Отправляем прогресс в сцену LoadingScreen
				var loading_screen = get_tree().current_scene
				if loading_screen.has_method("set_progress"):
					loading_screen.set_progress(progress_array[0] * 100)

		ResourceLoader.THREAD_LOAD_LOADED:
			var resource = ResourceLoader.load_threaded_get(scene_path)
			get_tree().change_scene_to_packed(resource)

			# Вызываем callback после небольшой задержки
			if callback_object != null and callback_method != "":
				get_tree().create_timer(0.2).timeout.connect(func():
					if is_instance_valid(callback_object):
						callback_object.call(callback_method)
				)

			emit_signal("scene_loaded")
			set_process(false)
			scene_path = ""

		ResourceLoader.THREAD_LOAD_FAILED:
			var loading_screen = get_tree().current_scene
			if loading_screen.has_method("show_error"):
				loading_screen.show_error()
			set_process(false)
			scene_path = ""
