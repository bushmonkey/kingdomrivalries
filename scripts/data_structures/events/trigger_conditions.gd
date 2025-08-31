# This resource holds all the conditions that must be met for an event to fire.
class_name TriggerConditions
extends Resource

# --- Player State Triggers ---
# Set these in the Inspector for each event.
@export var requires_player_is_married: bool = false
@export var requires_player_is_unmarried: bool = false
@export var requires_player_is_courting: bool = false
@export var requires_player_is_not_courting: bool = false
@export var requires_spouse_is_not_pregnant: bool = false
# --- Kingdom State Triggers ---
@export var min_gold: int = 0
@export var max_gold: int = 100 #bankrupcy
@export var min_food: int = 0
@export var max_food: int = 100 #famine
@export var requires_is_at_war: bool = false
@export var requires_is_at_peace: bool = false
@export_flags("Spring", "Summer", "Autumn", "Winter") var allowed_seasons: int = 15
#-----rival kingdoms triggers---
@export var requires_friendly_rival: bool = false
@export var requires_unfriendly_rival: bool = false

#------neighbouring kingdom triggers---
@export var requires_empty_neighboring_province: bool = false
@export var requires_coastal_province: bool = false

# --- Opinion Triggers ---
@export var max_nobility_opinion: int = 100 # e.g., for a rebellion event
@export var min_nobility_opinion: int = 0 # when they are really happy
@export var max_public_opinion: int = 100 # eg for a public lynching
@export var min_public_opinion: int = 0 #when they are really happy
