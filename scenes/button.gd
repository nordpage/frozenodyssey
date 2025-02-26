extends Button

var option_index: int = -1
var parent_card: Node

func setup(option_text: String, index: int, parent_ref: Node):
	text = option_text
	option_index = index
	parent_card = parent_ref
	pressed.connect(_on_button_pressed)

func _on_button_pressed():
	if parent_card:
		parent_card._on_option_selected(option_index)
	else:
		print("❌ Ошибка: Родительской карточки нет!")
