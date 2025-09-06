class_name Kingdom

var _treasury: float = 0.0
var _food: int = 500
var _manpower: int = 0

var id: int
var kingdom_name: String
var ruler: Character
var capital: Province
var provinces_owned: Array[Province] = []
var player_kingdom: bool = false
var color: Color

var relations: Dictionary = {}
var allies: Array[int] = [] # Stores the IDs of allied kingdoms
var rivals: Array[int] = [] # Stores the IDs of rival kingdoms

var treasury: float:
	get:
		return _treasury
	set(value):
		_treasury = max(0, value)
		
var manpower: int:
	get:
		return _manpower
	set(value):
		_manpower = max(0, value)
		
var science: int

var food: int:
	get:
		return _food
	set(value):
		_food = max(0, value)
		
var monthly_gold_change: float = 0.0
var monthly_food_change: int = 0

var nobility_opinion: int = 50
var public_opinion: int = 50
var church_opinion: int = 50
var traders_opinion: int = 50

var active_modifiers: Array[Modifier] = []

func get_military_strength() -> float:
	var ruler_bonus = 1.0 + (ruler.martial / 20.0)
	var money_bonus = 1.0 + (treasury / 5000.0)
	return manpower * ruler_bonus * money_bonus

func get_neighboring_kingdoms() -> Array[Kingdom]:
	var neighbors: Array[Kingdom] = []
	for my_province in provinces_owned:
		for neighbor_province in my_province.neighbors:
			if neighbor_province.owner != null and neighbor_province.owner != self:
				if not neighbors.has(neighbor_province.owner):
					neighbors.append(neighbor_province.owner)
	return neighbors
	
func has_modifier(modifier_id: String) -> bool:
	for modifier in active_modifiers:
		if modifier.id == modifier_id:
			return true
	return false

func get_neighboring_unowned_provinces() -> Array[Province]:
	var unowned_neighbors: Array[Province] = []
	
	# Loop through every province this kingdom owns
	for my_province in provinces_owned:
		# Loop through each neighbor of that province
		for neighbor_province in my_province.neighbors:
			# --- THE CRUCIAL CHECK ---
			# We check if the neighbor province's owner is NOT valid (i.e., it's null).
			if not is_instance_valid(neighbor_province.owner):
				# Ensure we haven't already added this province to our list
				# (in case two of our provinces border the same unowned one).
				if not unowned_neighbors.has(neighbor_province):
					unowned_neighbors.append(neighbor_province)
						
	return unowned_neighbors
	
# A clean way to add a new modifier to the kingdom.
func add_modifier(modifier_id: String, duration_in_months: int, value: Variant = 0,stackable: bool=false, char_id: String = ""):
	if not stackable:
			for mod in active_modifiers:
				if mod.id == modifier_id:
					# It already exists, so just refresh its duration and value.
					mod.duration_in_months = duration_in_months
					mod.value = value
					print("Refreshed non-stackable modifier '%s' on %s." % [modifier_id, kingdom_name])
					return
			
	# If we get here, the modifier doesn't exist yet, so we add a new one.
	var new_modifier = Modifier.new(modifier_id, duration_in_months, value,char_id)
	active_modifiers.append(new_modifier)
	print("Added modifier '%s' to %s (Duration: %d, Value: %s)" % [modifier_id, kingdom_name, duration_in_months, str(value)])
	

func remove_modifier(modifier_id: String):
	for i in range(active_modifiers.size() - 1, -1, -1):
		if active_modifiers[i].id == modifier_id:
			active_modifiers.remove_at(i)
			print("Removed one-time use modifier '%s' from %s." % [modifier_id, kingdom_name])
			# We break here to only remove the first one we find.
			break
