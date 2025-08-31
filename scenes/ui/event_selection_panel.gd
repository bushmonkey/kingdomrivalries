extends PanelContainer

# This signal will pass the chosen GameEvent object back to the MainView.
signal event_selected(event_resource)
signal selection_cancelled

const EventChoiceButtonScene = preload("res://scenes/ui/event_choice_button.tscn")

@onready var title_label = %Title
@onready var event_options_container = %Eventoptions

# Takes an array of 3 GameEvent objects to display.
func display_choices(event_choices: Array[GameEvent]):
	# Clear any old buttons
	for child in event_options_container.get_children():
		child.queue_free()
	
	# --- THE REFACTORED LOOP ---
	for event in event_choices:
		if not is_instance_valid(event): continue
		
		# 1. Instance our pre-designed scene.
		var choice_button = EventChoiceButtonScene.instantiate()
		event_options_container.add_child(choice_button)
		
		# 2. Call its setup function to populate it with data.
		choice_button.set_event_data(event)
		
		# 3. Connect its 'pressed' signal to our handler.
		#    The root of the scene is a Button, so we can connect to it directly.
		choice_button.pressed.connect(_on_event_button_pressed.bind(event))
		


func _on_event_button_pressed(event_resource: GameEvent):
	emit_signal("event_selected", event_resource)
