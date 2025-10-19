extends Button

# This script is attached to the root 'UnitButton' node.

@onready var unit_icon = %UnitIcon
@onready var unit_name_label = %UnitNameLabel
@onready var unit_count_label = %UnitCountLabel

# --- A dictionary to map unit types to their icons ---
# This is much cleaner than a big 'match' statement.
const UNIT_ICONS = {
	BattleUnit.UnitType.FOOT_SOLDIER: preload("res://assets/icons/units/foot_soldier_icon.png"),
	BattleUnit.UnitType.CAVALRY: preload("res://assets/icons/units/cavalry_icon.png"),
	BattleUnit.UnitType.PIKEMAN: preload("res://assets/icons/units/pikeman_icon.svg"),
	BattleUnit.UnitType.KNIGHT: preload("res://assets/icons/units/knight_icon.svg"),
	BattleUnit.UnitType.CANNON: preload("res://assets/icons/units/cannon_icon.svg")
}

var unit_type: BattleUnit.UnitType

# This is the public "front door" function that the BattleView will call.
func set_unit_data(unit: BattleUnit):
	# Set the unit's name. We get the string name from the enum's keys.
	var unit_name = BattleUnit.UnitType.keys()[unit.unit_type].capitalize().replace("_", " ")
	unit_name_label.text = unit_name
	
	# Set the unit's count.
	unit_count_label.text = "Count: %d" % unit.count
	
	# Set the icon from our dictionary.
	if UNIT_ICONS.has(unit.unit_type):
		unit_icon.texture = UNIT_ICONS[unit.unit_type]
		
	# If the unit count is 0, disable the button.
	if unit.count <= 0:
		self.disabled = true
		
func highlight(is_on: bool):
	if is_on:
		# Use modulate to make it glow. A yellow tint works well.
		self.modulate = Color.GOLD
	else:
		# Reset to the default color.
		self.modulate = Color.WHITE 
