# BaseLocationPoint.gd
extends Area2D

var location_id: String
var location_type: String = "base"
var is_active: bool = false
var is_disabled: bool = false
var parent_id: String = ""
var children_ids: Array = []
var has_children: bool = false
var is_expanded: bool = false
var title: String = ""
var description: String = ""
var date_range: String = ""
var diary: String = ""
var coordinates: Vector2

# Сигналы
signal location_selected(location_id: String)
signal location_mouse_enter(location_id: String)
signal location_mouse_exit(location_id: String)
signal location_expand(location_id: String)
signal location_collapse(location_id: String)

func _ready():
	self.connect("input_event", Callable(self, "_on_input_event"))
	self.mouse_entered.connect(func(): emit_signal("location_mouse_enter", location_id))
	self.mouse_exited.connect(func(): emit_signal("location_mouse_exit", location_id))
	update_appearance()

# В BaseLocationPoint.gd обновите функцию _on_input_event:
# Улучшенная функция _on_input_event для BaseLocationPoint.gd
# Исправленная версия _on_input_event в BaseLocationPoint.gd
# In BaseLocationPoint.gd
func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Клик на локации:", location_id, "(", location_type, ")")
		
		# Если точка отключена - игнорируем клик
		if is_disabled:
			return
			
		# Прерываем событие
		get_viewport().set_input_as_handled()
		
		# Сигнал о выборе локации
		emit_signal("location_selected", location_id)
		
		# Разворачивание/сворачивание только для определенных типов
		if (location_type == "stage" or location_type == "group") and has_children:
			if is_expanded:
				# Сворачиваем
				emit_signal("location_collapse", location_id)
				is_expanded = false
			else:
				# Разворачиваем
				emit_signal("location_expand", location_id)
				is_expanded = true

func set_active(active: bool):
	is_active = active
	is_disabled = false
	update_appearance()

func set_disabled():
	if is_active:  # Не блокировать активную точку
		return
		
	is_disabled = true
	set_process_input(false)
	input_pickable = false
	update_appearance()

func set_enabled():
	is_active = false
	is_disabled = false
	set_process_input(true)
	input_pickable = true
	update_appearance()

func set_children(children: Array):
	children_ids = children
	has_children = children.size() > 0
	
	# Визуальное отображение наличия дочерних элементов
	if has_children:
		# Здесь можно добавить индикатор дочерних элементов
		pass

func update_appearance():
	# Будет переопределена в дочерних классах
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		if is_active:
			sprite.texture = load("res://icon.png")
		elif is_disabled:
			sprite.texture = load("res://icon.png")
		else:
			sprite.texture = load("res://icon.png")
