# This class represents a temporary (or permanent) effect on a character or kingdom.
class_name Modifier
extends RefCounted

# The unique identifier for this modifier, e.g., "FestivalSpirit".
var id: String
var instance_id: String
# How many months this modifier will last. A value of -1 means permanent.
var duration_in_months: int
var value: Variant
#A way to link a modifier to a specific character ---
var attached_character_id: String = ""

func _init(p_id: String, p_duration: int, p_value: Variant = 0, p_char_id: String = ""):
	self.instance_id = str(Time.get_ticks_msec()) + "_" + p_id
	self.id = p_id
	self.duration_in_months = p_duration
	self.value = p_value
	self.attached_character_id = p_char_id
