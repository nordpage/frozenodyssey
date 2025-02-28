extends Area2D
@export var default_texture: Texture
@export var active_texture: Texture
@export var disabled_texture: Texture  # Текстура для заблокированной точки
@export var title: String = ""
@export var description: String = ""
var location_id: String
var is_active: bool = false
signal location_selected(location_id: String)

func _ready():
	# В Godot 4 подключение сигналов
	self.connect("input_event", Callable(self, "_on_input_event"))
	set_active(false)
			
func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var shape = $CollisionShape2D.shape
		var local_pos = to_local(mouse_pos)
		
		var is_inside = false
		if shape is CircleShape2D:
			is_inside = local_pos.length() < shape.radius
		elif shape is RectangleShape2D:
			is_inside = abs(local_pos.x) < shape.size.x/2 and abs(local_pos.y) < shape.size.y/2
			
		if is_inside:
			AudioManager.play_sound("move")
		# Не нужно отправлять сигнал и перемещаться - выберите один способ
			var parent = get_parent()
			if parent.has_method("move_to_location"):
				parent.move_to_location(location_id)
				get_viewport().set_input_as_handled()

# В location_point.gd
func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Клик обнаружен через _on_input_event:", location_id)
		var parent = get_parent()
		if parent.has_method("move_to_location"):
			parent.move_to_location(location_id)
		
func set_active(active: bool):
	is_active = active
	var sprite = get_node("Sprite2D")
	sprite.texture = active_texture if active else default_texture
	
func set_disabled():
	if is_active:  # Не блокировать активную точку
		return
	print("🔒 Блокировка:", location_id)
	is_active = false
	set_process_input(false)
	input_pickable = false
	get_node("Sprite2D").texture = disabled_texture

func set_enabled():
	is_active = false
	set_process_input(true)   # Включаем обработку _input
	input_pickable = true     # Включаем возможность выбора (добавьте эту строку)
	get_node("Sprite2D").texture = default_texture
