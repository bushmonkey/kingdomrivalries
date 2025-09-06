# Defines a single choice/button within an event.
class_name EventOption
extends Resource

@export_multiline var text: String = "Choice Text" # Text on the button
@export_multiline var success_text: String = "Success!"
@export_multiline var failure_text: String = "Failure!"

# We can directly embed our other custom resources here!
@export var skill_check: SkillCheck

@export var required_gold: int = 0
@export var required_manpower: int = 0
@export var required_food: int = 0
@export var required_modifier: String = ""

# And here we define an array of our EventOutcome resources.
@export var success_outcomes: Array[EventOutcome]
@export var failure_outcomes: Array[EventOutcome]
