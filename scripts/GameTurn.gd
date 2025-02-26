extends Node
class_name GameTurn

@export var turn_number: int = 1
@export var resource_changes: Dictionary = {}

func apply_turn(game_resources: GameResources):
	for key in resource_changes.keys():
		game_resources.modify_resource(key, resource_changes[key])

	print("📆 Turn", turn_number, "applied! Changes:", resource_changes)
