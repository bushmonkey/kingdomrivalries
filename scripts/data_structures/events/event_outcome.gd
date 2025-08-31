# Defines a single mechanical outcome of a choice.
class_name EventOutcome
extends Resource

@export var type: String # e.g., "ChangeResource", "ChangeOpinion", "AddModifier"
@export var target: String # e.g., "Gold", "Public", "Nobility", "Player"
@export var value: int # Can be an int for gold, a string for a modifier name, etc
@export var duration: int =0
@export var stackable: bool =false
