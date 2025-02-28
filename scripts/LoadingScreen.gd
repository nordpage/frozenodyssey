# LoadingScreen.gd
extends Control

@onready var progress_bar = $VBoxContainer/ProgressBar
@onready var label = $VBoxContainer/Label

var scene_path = ""
var callback_object = null
var callback_method = ""

func _ready():
	hide()

func load_scene(path, cb_object = null, cb_method = ""):
	scene_path = path
	callback_object = cb_object
	callback_method = cb_method
	
	show()
	progress_bar.value = 0
	
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
				progress_bar.value = progress_array[0] * 100
			label.text = "Загрузка: %d%%" % [progress_bar.value]
			
		ResourceLoader.THREAD_LOAD_LOADED:
			var resource = ResourceLoader.load_threaded_get(scene_path)
			get_tree().change_scene_to_packed(resource)
			
			# Вызываем callback после небольшой задержки
			if callback_object != null and callback_method != "":
				get_tree().create_timer(0.2).timeout.connect(func():
					if is_instance_valid(callback_object):
						callback_object.call(callback_method)
				)
			
			hide()
			set_process(false)
			scene_path = ""
			
		ResourceLoader.THREAD_LOAD_FAILED:
			label.text = "Ошибка загрузки!"
			set_process(false)
			scene_path = ""
