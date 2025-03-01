# GroupPoint.gd
extends "res://scripts/points/BaseLocationPoint.gd"

func _ready():
	location_type = "group"
	super._ready()

func update_appearance():
	var sprite = get_node_or_null("Sprite2D")
	if not sprite:
		return
		
	if is_active:
		sprite.texture = load("res://assets/group_icon_active.png")
	elif is_disabled:
		sprite.texture = load("res://assets/group_icon_disabled.png")
	else:
		sprite.texture = load("res://assets/group_icon.png")
	
	# Размер иконки группы немного больше обычных
	sprite.scale = Vector2(1.4, 1.4)
