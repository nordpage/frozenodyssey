# Create this file as ActionCardUI.gd
extends PanelContainer

@onready var title_label = $VBoxContainer/Title
@onready var description_label = $VBoxContainer/Description
@onready var apply_button = $VBoxContainer/ApplyButton

# You can add this to your scene hierarchy:
# PanelContainer (ActionCardUI.gd)
#  └─ VBoxContainer
#     ├─ Label (Title)
#     ├─ Label (Description) 
#     └─ Button (ApplyButton) with text "Apply"

func _ready():
	if not title_label or not description_label or not apply_button:
		print("❌ Error: Some child nodes not found in ActionCardUI!")
