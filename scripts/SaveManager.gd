# SaveManager.gd
extends Node

const SAVE_PATH = "user://save.dat"

func save_game(map_node):
	var save_data = {
		"active_location": map_node.active_location_id,
		"visited_locations": map_node.visited_locations,
		"resources": {},
		"current_turn": map_node.current_turn,
		"current_date": map_node.current_date
	}
	
	# Сохраняем ресурсы
	var game_resources = map_node.game_resources
	for res_name in game_resources.resources.keys():
		var resource = game_resources.resources[res_name]
		save_data["resources"][res_name] = {
			"amount": resource.amount,
			"max_amount": resource.max_amount
		}
	
	# Записываем в файл
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_var(save_data)
	
func load_game(map_node):
	if not FileAccess.file_exists(SAVE_PATH):
		return false
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var save_data = file.get_var()
	
	# Загружаем данные
	map_node.active_location_id = save_data["active_location"]
	map_node.visited_locations = save_data["visited_locations"]
	map_node.current_turn = save_data["current_turn"]
	map_node.current_date = save_data["current_date"]
	
	# Загружаем ресурсы
	var game_resources = map_node.game_resources
	for res_name in save_data["resources"].keys():
		var res_data = save_data["resources"][res_name]
		if game_resources.resources.has(res_name):
			game_resources.resources[res_name].amount = res_data["amount"]
			game_resources.resources[res_name].max_amount = res_data["max_amount"]
	
	# Обновляем визуальное состояние
	map_node.update_active_location(map_node.active_location_id)
	
	return true
