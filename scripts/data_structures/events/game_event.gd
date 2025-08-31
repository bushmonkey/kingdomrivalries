# This is the top-level resource for a complete game event.
class_name GameEvent
extends Resource

# --- NEW: The Category Property ---
# This tells us which decision bucket this event belongs to.
# Use an enum for type-safety and autocompletion.
enum EventCategory {
	RANDOM, # For the mandatory end-of-month event
	ECONOMIC,
	AGRICULTURE,
	MANUFACTURING,
	SPECIAL,
	CULTURE,
	PERSONAL_GROWTH,
	MILITARY
}

enum EventRarity {
	COMMON,
	UNCOMMON,
	RARE
}

@export var category: EventCategory
@export var trigger_conditions: TriggerConditions

@export var event_id: String
@export var title: String
@export var unlocked_at_start: bool = true
@export var rarity: EventRarity = EventRarity.COMMON
@export var cooldown_years: int = 0
@export var selection_cost: int = 0 # The gold cost to choose this event from the popup
@export_multiline var summary: String
@export_multiline var description: String
@export_file("*.png", "*.jpg") var vignette_texture: String

# TODO: Add trigger condition properties here if needed
# e.g., @export var min_gold: int = 0
# @export var requires_war: bool = false

# This will be an array of our EventOption resources.
@export var options: Array[EventOption]
