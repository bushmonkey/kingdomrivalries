extends PanelContainer
class_name GenericDecisionPanel

signal choice_made(choice_id)

@onready var title_label := %Title
@onready var options_container := %OptionsContainer

# options is an array of dictionaries: [{"id": "invest", "text": "Invest in Troops"}]
func set_options(panel_title: String, options: Array):
	# This check is good practice for debugging.
	if not is_instance_valid(title_label):
		printerr("ERROR: Title node not found in GenericDecisionPanel!")
		return

	# This line should now work perfectly.
	title_label.text = panel_title
	
	# Clear old buttons
	for child in options_container.get_children():
		child.queue_free()

	for option in options:
		var button = Button.new()
		button.text = option.text
		button.pressed.connect(_on_button_pressed.bind(option.id))
		options_container.add_child(button)

func _on_button_pressed(choice_id: String):
	emit_signal("choice_made", choice_id)
