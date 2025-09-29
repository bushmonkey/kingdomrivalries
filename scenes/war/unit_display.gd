extends PanelContainer


@onready var unit_name_label = %UnitName
@onready var unit_count_label = %UnitCount

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func set_unit_data(unit: BattleUnit):
	# Set the unit's name. We get the string name from the enum's keys.
	var unit_name = BattleUnit.UnitType.keys()[unit.unit_type].capitalize().replace("_", " ")
	unit_name_label.text = unit_name
	
	# Set the unit's count.
	unit_count_label.text = "Count: %d" % unit.count

		
	# If the unit count is 0, disable the button.
	if unit.count <= 0:
		self.disabled = true
