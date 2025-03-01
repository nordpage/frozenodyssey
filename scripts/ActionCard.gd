# ActionCard.gd
# Этот класс хранит данные одной карточки действия.
extends RefCounted
class_name ActionCard

var id: String
var title: String
var title_en: String
var description: String
var description_en: String
var boost: Dictionary
var points: int

func _init(_id: String, _title: String, _title_en: String, _description: String, _description_en: String, _boost: Dictionary, _points: int) -> void:
	id = _id
	title = _title
	title_en = _title_en
	description = _description
	description_en = _description_en
	boost = _boost
	points = _points
