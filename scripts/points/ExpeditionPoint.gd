# ExpeditionPoint.gd
extends "res://scripts/points/BaseLocationPoint.gd"

func _ready():
	location_type = "expedition"
	super._ready()

func update_appearance():
	var sprite = get_node_or_null("Sprite2D")
	if not sprite:
		return
		
	if is_active:
		sprite.texture = load("res://assets/expedition_icon_active.png")
	elif is_disabled:
		sprite.texture = load("res://assets/expedition_icon_disabled.png")
	else:
		sprite.texture = load("res://assets/expedition_icon.png")
	
	# Размер иконки экспедиции больше обычных
	sprite.scale = Vector2(2.0, 2.0)
