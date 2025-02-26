extends PanelContainer

@export var title_label: Label
@export var description_label: Label
@export var options_container: VBoxContainer
@export var apply_button: Button  # ❗ Теперь просто указываем кнопку

var event_data: EventCard
var game_resources: GameResources

func setup(event: EventCard, resources: GameResources):
	event_data = event
	game_resources = resources

	# Устанавливаем текст заголовка и описания
	if title_label and description_label:
		title_label.text = event.title
		description_label.text = event.description
	else:
		print("❌ Ошибка: title_label или description_label не привязаны!")

	# Подключаем кнопку
	if apply_button:
		apply_button.pressed.connect(_on_option_selected.bind(0))  # ❗ Используем фиксированный индекс 0
	else:
		print("❌ Ошибка: apply_button не найден!")

	visible = true

func _on_option_selected(index):
	event_data.apply_option(index, game_resources)
	queue_free()  # Закрываем карточку после выбора
