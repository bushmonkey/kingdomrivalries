extends PanelContainer

signal option_chosen(choice_data: EventOption)

@onready var title_label = %Title
@onready var description_label = %Description
@onready var options_container = %OptionsContainer
@onready var vignette_display = %VignetteDisplay 

func display_event(prepared_event: PreparedEvent):
	# First, check if we received a valid event object.
	# This prevents crashes if something goes wrong in the EventManager.
	# 2. Create an empty dictionary to hold our format arguments
	
	var event_data = prepared_event.event_resource
	var format_args = prepared_event.format_args
	var final_text = event_data.description
	var player_ruler = GameManager.player_kingdom.ruler
	
	
	
	if not is_instance_valid(event_data):
		printerr("EventPanel received an invalid event data object.")
		title_label.text = "Error: Event Not Found"
		description_label.text = "Could not load the event. Please check the logs."
		return

	# --- No more .get() calls! We access properties directly. ---
	title_label.text = event_data.title
	description_label.text = event_data.description.format(format_args, "{_}")

	if not event_data.vignette_texture.is_empty():
		# Load the texture from the path specified in the resource.
		var texture = load(event_data.vignette_texture)
		vignette_display.texture = texture
		vignette_display.show() # Make sure it's visible
	else:
			# If no texture is defined for this event, hide the display.
			vignette_display.hide()
	
	# Clear any old buttons from a previous event.
	for child in options_container.get_children():
		child.queue_free()

	# Loop through the options array within our GameEvent resource.
	# The 'option' variable is now known to be an EventOption resource.
	for option in event_data.options:
		var button = Button.new()
		var final_option_text=option.text
		var player_kingdom = GameManager.player_kingdom
		var can_afford = true
		var reason = ""
		
		if not format_args.is_empty():
			final_option_text = final_option_text.format(format_args, "{_}")
		# Access the 'text' property directly and safely.
		button.text = final_option_text
		
		if player_kingdom.treasury < option.required_gold:
			can_afford = false
			reason = "Not enough Gold (requires %d)" % option.required_gold
		elif player_kingdom.manpower < option.required_manpower:
			can_afford = false
			reason = "Not enough Manpower (requires %d)" % option.required_manpower
		elif player_kingdom.food < option.required_food:
			can_afford = false
			reason = "Not enough Food (requires %d)" % option.required_food
			
		if not can_afford:
			button.disabled = true
			# The tooltip is a great UX feature.
			button.tooltip_text = reason
			
		var choice_package = {
			"event": event_data, # Include the GameEvent itself
			"option": option,
			"format_args": format_args
		}
		
		button.pressed.connect(_on_option_button_pressed.bind(choice_package))
		
		options_container.add_child(button)
	
	# Make the panel visible after setting it up.
	self.show()

func _on_option_button_pressed(choice_package: Dictionary):
	# --- ADD THIS PRINT STATEMENT ---
	print("DEBUG: Button pressed in EventPanel! Emitting option_chosen.")
	self.hide()
	emit_signal("option_chosen", choice_package)
