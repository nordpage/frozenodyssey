extends Node
class_name GameResources

var resources: Dictionary = {}

func _ready():
	# Initialize core resources
	resources["Temperature"] = ResourceData.new()
	resources["Temperature"].name = "Temperature"
	resources["Temperature"].description = "Freezing cold threatens survival."
	resources["Temperature"].amount = 50
	resources["Temperature"].max_amount = 100

	resources["Food"] = ResourceData.new()
	resources["Food"].name = "Food"
	resources["Food"].description = "Supplies that keep you alive."
	resources["Food"].amount = 50
	resources["Food"].max_amount = 100

	resources["Energy"] = ResourceData.new()
	resources["Energy"].name = "Energy"
	resources["Energy"].description = "Your stamina and ability to move."
	resources["Energy"].amount = 50
	resources["Energy"].max_amount = 100

	resources["Morale"] = ResourceData.new()
	resources["Morale"].name = "Morale"
	resources["Morale"].description = "Mental strength and willpower."
	resources["Morale"].amount = 50
	resources["Morale"].max_amount = 100

func get_resource(name: String) -> ResourceData:
	return resources.get(name, null)

func modify_resource(name: String, value: int):
	if resources.has(name):
		if value > 0:
			resources[name].add(value)
		else:
			resources[name].subtract(abs(value))
