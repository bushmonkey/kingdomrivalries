extends Button

@onready var title_label = %TitleLabel
@onready var description_label = %DescriptionLabel
@onready var cost_label = %CostLabel

# This is the public "setup" function that the parent panel will call.
func set_event_data(event: GameEvent):
	# Set the title text using BBCode for bolding.
	title_label.text = "[b]%s[/b]" % event.title
	
	if not event.summary.is_empty():
		description_label.text = "[i]%s[/i]" % event.summary
	else:
	# Set the description, trimming it to a reasonable length.
		description_label.text = "[i]%s[/i]" % event.description.left(120) + "..."
	
	# Set the cost text, or hide the label if there is no cost.
	if event.selection_cost > 0:
		cost_label.show()
		cost_label.text = "[color=yellow]Cost: %d Gold[/color]" % event.selection_cost
	else:
		cost_label.hide()
		
	# Disable the entire button if the player can't afford the event.
	if GameManager.player_kingdom.treasury < event.selection_cost:
		self.disabled = true
