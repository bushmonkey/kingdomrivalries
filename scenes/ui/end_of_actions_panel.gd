extends PanelContainer

signal continue_to_random_event

@onready var continue_button = %ContinueButton

func _ready():
	continue_button.pressed.connect(func(): emit_signal("continue_to_random_event"))
