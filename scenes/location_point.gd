extends Area2D

@export var default_texture: Texture
@export var active_texture: Texture
@export var disabled_texture: Texture
@export var stage_texture: Texture
@export var group_texture: Texture

@export var title: String = ""
@export var description: String = ""
@export var date_range: String = ""
@export var diary: String = ""

var location_id: String
var location_type: String = "point" # "expedition", "stage", "group", "point"
var is_active: bool = false
var has_children: bool = false
var is_expanded: bool = false
var parent_id: String = ""
var children_ids: Array = []
var coordinates: Vector2

signal location_selected(location_id: String)
signal location_mouse_enter(location_id: String)
signal location_mouse_exit(location_id: String)
signal location_expand(location_id: String)
signal location_collapse(location_id: String)

func _ready():
	# В Godot 4 подключение сигналов
	self.connect("input_event", Callable(self, "_on_input_event"))
	self.mouse_entered.connect(func(): emit_signal("location_mouse_enter", location_id))  
	self.mouse_exited.connect(func(): emit_signal("location_mouse_exit", location_id))
	
	# Устанавливаем текстуру в зависимости от типа локации
	update_texture()
	set_active(false)

func update_texture():
	var sprite = get_node("Sprite2D")
	match location_type:
		"expedition":
			sprite.texture = default_texture
			scale = Vector2(2.0, 2.0)
		"stage":
			sprite.texture = stage_texture
			scale = Vector2(1.7, 1.7)
		"group":
			sprite.texture = group_texture
			scale = Vector2(1.4, 1.4)
		"point", _:
			sprite.texture = default_texture
			scale = Vector2(1.0, 1.0)
			
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
			
			# Если точка имеет детей и не развернута - раскрываем
			if has_children and not is_expanded:
				is_expanded = true
				emit_signal("location_expand", location_id)
				return
			# Если точка уже развернута - сворачиваем
			elif has_children and is_expanded:
				is_expanded = false
				emit_signal("location_collapse", location_id)
				return
				
			# Для конечных точек или когда развернуто - перемещаемся
			var parent = get_parent()
			if parent.has_method("move_to_location"):
				parent.move_to_location(location_id)
				get_viewport().set_input_as_handled()

func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Клик обнаружен через _on_input_event:", location_id, " (", location_type, ")")
		
		# Логика раскрытия/сворачивания, как в _input
		if has_children and not is_expanded:
			is_expanded = true
			emit_signal("location_expand", location_id)
			return
		elif has_children and is_expanded:
			is_expanded = false
			emit_signal("location_collapse", location_id)
			return
		
		var parent = get_parent()
		if parent.has_method("move_to_location"):
			parent.move_to_location(location_id)
		
func set_active(active: bool):
	is_active = active
	var sprite = get_node("Sprite2D")
	
	if active:
		sprite.texture = active_texture
	else:
		update_texture()
	
func set_disabled():
	if is_active:  # Не блокировать активную точку
		return
		
	is_active = false
	set_process_input(false)
	input_pickable = false
	get_node("Sprite2D").texture = disabled_texture

func set_enabled():
	is_active = false
	set_process_input(true)   # Включаем обработку _input
	input_pickable = true     # Включаем возможность выбора
	update_texture()
	
func set_children(children: Array):
	children_ids = children
	has_children = children.size() > 0
	
	# Визуальное отображение наличия дочерних элементов
	if has_children:
		# Можно добавить специальный индикатор
		var indicator = get_node_or_null("ChildrenIndicator")
		if indicator:
			indicator.visible = true
