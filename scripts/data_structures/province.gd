class_name Province

# --- Properties ---

enum BuildingType {
	NONE,
	FARM,
	MINE,
	GRANARY
}

enum ProvinceType {
	PLAINS,      # Standard, balanced province
	BOUNTIFUL,   # Extra food
	MOUNTAINOUS, # Guaranteed mine
	FOREST,      # Potential for lumber/hunting income
	COASTAL_FISHING_VILLAGE # Extra food AND coastal gold
}

# The unique identifier for this province, matching the ID from map_data.json.
var id: int

# The display name of the province, e.g., "Wessex", "Dublin".
var province_name: String
var type: ProvinceType = ProvinceType.PLAINS 
# A direct reference to the Kingdom object that currently owns this province.
# If null, the province is unowned or controlled by rebels.
var owner: Kingdom

# An array holding direct references to all neighboring Province objects.
# This is the core of the map graph, defining borders for trade and war.
var neighbors: Array[Province] = []
var maintenance_cost: int = 10 # Base cost to maintain control of the province
var has_farm: bool = false
var has_mine: bool = false
var has_granary: bool = false
var is_coastal: bool = false
var buildings: Array[BuildingType] =[]
# --- Initialization ---

# The constructor method, called when you create a new Province.
# Example: var new_province = Province.new(0, "Dublin")
func _init(p_id: int, p_name: String):
	self.id = p_id
	self.province_name = p_name
	self.maintenance_cost = randi_range(5, 15)

# --- Methods ---

# A utility function to link this province to its neighbors.
# This makes setting up the map graph cleaner in the WorldGenerator.
# You would call this after all province objects have been created.
# Example: province_a.add_neighbor(province_b)
func add_neighbor(neighbor_province: Province):
	# Check to ensure we don't add the same neighbor twice.
	if not neighbors.has(neighbor_province):
		neighbors.append(neighbor_province)

# A simple string representation for debugging purposes.
# Calling print(my_province) will now show something useful.
func _to_string() -> String:
	var owner_name = "Unowned"
	if owner:
		owner_name = owner.kingdom_name
	return "Province %s (ID: %d, Owner: %s)" % [province_name, id, owner_name]
