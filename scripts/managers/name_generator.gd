extends Node

# This will be an Autoload, so it's globally accessible.

# A dictionary to hold different cultural name lists.
# This allows you to easily add more later (e.g., Irish, Scottish).
var name_lists: Dictionary = {}

func _ready():
	# Load our name list resource when the game starts.
	# We give it a key, "anglosaxon", so we can ask for it by name.
	name_lists["anglosaxon"] = load("res://data/names/name_list_anglosaxon.tres")
	print("NameGenerator loaded.")

# --- Public Functions ---

# Gets a random first name.
func get_random_first_name(gender: Character.Gender, culture: String = "anglosaxon") -> String:
	if not name_lists.has(culture):
		printerr("NameGenerator: Culture '%s' not found." % culture)
		return "Unknown"
		
	var list_to_use: Array[String]
	var name_list: NameList = name_lists[culture]

	if gender == Character.Gender.MALE:
		list_to_use = name_list.male_names
	else:
		list_to_use = name_list.female_names
	
	if list_to_use.is_empty():
		return "Nameless"
		
	return list_to_use.pick_random()

# Gets a random dynasty name.
func get_random_dynasty_name(culture: String = "anglosaxon") -> String:
	if not name_lists.has(culture):
		printerr("NameGenerator: Culture '%s' not found." % culture)
		return "of Nowhere"
	
	var name_list: NameList = name_lists[culture]
	var list_to_use = name_list.dynasty_names
	
	if list_to_use.is_empty():
		return "Landless"
		
	return list_to_use.pick_random()
	
func get_random_common_name(culture: String = "anglosaxon") -> String:
	if not name_lists.has(culture):
		printerr("NameGenerator: Culture '%s' not found." % culture)
		return "of Nowhere"
	
	var name_list: NameList = name_lists[culture]
	var list_to_use = name_list.common_names
	
	if list_to_use.is_empty():
		return "Landless"
		
	return list_to_use.pick_random()
	
func get_dynasty_name_list(culture: String = "anglosaxon") -> Array[String]:
	if not name_lists.has(culture):
		printerr("NameGenerator: Culture '%s' not found." % culture)
		return []
	
	var name_list: NameList = name_lists[culture]
	
	# Return a DUPLICATE of the array. This is very important.
	# It prevents us from accidentally shuffling the original master list.
	return name_list.dynasty_names.duplicate()
