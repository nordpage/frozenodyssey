extends Resource
class_name ResourceData

@export var name: String = "Resource"
@export var description: String = ""
@export var amount: int = 100
@export var max_amount: int = 100

func add(value: int):
	amount = min(amount + value, max_amount)

func subtract(value: int):
	amount = max(amount - value, 0)

func is_empty() -> bool:
	return amount <= 0
